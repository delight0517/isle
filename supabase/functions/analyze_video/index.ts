// Isle — 영상 내러티브 분석 (자막 → LLM → Supabase 캐시)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const LANG_ORDER = ["ko", "a.ko", "en", "a.en", "ja"];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const body = await req.json();
    const videoId = String(body.videoId ?? "").trim();
    const title = String(body.title ?? "YouTube");
    const channelName = String(body.channelName ?? "");
    const durationSeconds = Number(body.durationSeconds ?? 0) || 0;

    if (videoId.length !== 11) {
      return json({ error: "invalid videoId" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "supabase not configured" }, 500);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: cached } = await admin
      .from("video_analyses")
      .select("narrative_json, title, channel_name")
      .eq("video_id", videoId)
      .maybeSingle();

    if (cached?.narrative_json) {
      const narrative = { ...cached.narrative_json, from_cache: true, analyzed_via_edge: true };
      return json(narrative, 200);
    }

    const transcript = await fetchYouTubeTranscript(videoId);
    if (!transcript || transcript.length < 40) {
      return json({ error: "no_captions", message: "자막(CC)이 없어 서버 분석을 할 수 없어요." }, 422);
    }

    const narrative = await analyzeWithLlm({
      videoId,
      title,
      channelName,
      durationSeconds,
      transcript,
    });

    await admin.from("video_analyses").upsert({
      video_id: videoId,
      title,
      channel_name: channelName,
      narrative_json: narrative,
      source: "edge",
      updated_at: new Date().toISOString(),
    });

    return json({ ...narrative, from_cache: false, analyzed_via_edge: true }, 200);
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

async function fetchYouTubeTranscript(videoId: string): Promise<string | null> {
  for (const lang of LANG_ORDER) {
    try {
      const url = `https://www.youtube.com/api/timedtext?v=${videoId}&lang=${lang}&fmt=srv3`;
      const res = await fetch(url, {
        headers: { "User-Agent": "Mozilla/5.0 (compatible; Isle/1.0)" },
      });
      if (!res.ok) continue;
      const raw = await res.text();
      const text = parseTimedText(raw);
      if (text && text.length >= 40) {
        return text.length > 14000 ? text.slice(0, 14000) + "…" : text;
      }
    } catch {
      continue;
    }
  }
  return null;
}

function parseTimedText(raw: string): string {
  if (!raw.includes("<")) {
    return raw.replace(/\s+/g, " ").trim();
  }
  const parts: string[] = [];
  const re = /<text[^>]*>([^<]*)<\/text>/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(raw)) !== null) {
    const t = m[1]
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&#39;/g, "'")
      .replace(/&quot;/g, '"')
      .trim();
    if (t) parts.push(t);
  }
  return parts.join(" ").replace(/\s+/g, " ").trim();
}

async function analyzeWithLlm(opts: {
  videoId: string;
  title: string;
  channelName: string;
  durationSeconds: number;
  transcript: string;
}): Promise<Record<string, unknown>> {
  const system = `You analyze WHY a YouTube video performed well — NOT a summary.
Output a single JSON object with keys:
- acts: array of {phase: hook|body|twist|cta, start_sec, end_sec, keywords: string[], emotion, summary} (Korean summaries)
- story_formula: Korean one line with arrows
- wpm: integer words per minute estimate
- rhythm_summary: Korean pacing/tone
- structural_insight: Korean — why this structure retains viewers
- originality_prompts: array of 2-4 Korean tips — "structure is borrowed, soul must be yours"
- differentiation_checklist: array of 3-5 Korean checklist items for the creator to add their unique angle
Ground analysis in the transcript. Hook often under 15 seconds.`;

  const user = `제목: ${opts.title}
채널: ${opts.channelName}
길이: ${opts.durationSeconds}s
video_id: ${opts.videoId}

자막:
${opts.transcript}`;

  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (anthropicKey) {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-3-5-haiku-20241022",
        max_tokens: 1200,
        system,
        messages: [{ role: "user", content: user }],
      }),
    });
    if (!res.ok) throw new Error(`anthropic ${res.status}`);
    const data = await res.json();
    const text = data.content?.[0]?.text ?? "";
    return parseNarrativeJson(text, opts);
  }

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) {
    throw new Error("OPENAI_API_KEY or ANTHROPIC_API_KEY required on Edge Function");
  }

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${openaiKey}`,
    },
    body: JSON.stringify({
      model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
      max_tokens: 1200,
      temperature: 0.35,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    }),
  });

  if (!res.ok) throw new Error(`openai ${res.status}`);
  const data = await res.json();
  const text = data.choices?.[0]?.message?.content ?? "";
  return parseNarrativeJson(text, opts);
}

function parseNarrativeJson(
  text: string,
  opts: { videoId: string; title: string; channelName: string },
): Record<string, unknown> {
  let raw = text.trim();
  const fence = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) raw = fence[1].trim();
  const map = JSON.parse(raw);
  return {
    video_id: opts.videoId,
    title: opts.title,
    channel_name: opts.channelName,
    acts: map.acts ?? [],
    story_formula: map.story_formula ?? "",
    wpm: map.wpm ?? 0,
    rhythm_summary: map.rhythm_summary ?? "",
    structural_insight: map.structural_insight ?? "",
    originality_prompts: map.originality_prompts ?? [],
    differentiation_checklist: map.differentiation_checklist ?? [],
    used_ai: true,
    used_captions: true,
    analyzed_at: new Date().toISOString(),
  };
}
