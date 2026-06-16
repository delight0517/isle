// Isle — YouTube CC → LLM insight → insight_nodes (모바일은 invoke만)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const LANG_ORDER = ["ko", "a.ko", "en", "a.en", "ja"];
const MAX_TRANSCRIPT = 15000;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "unauthorized", message: "로그인이 필요합니다." }, 401);
    }

    const body = await req.json();
    const videoUrl = String(body.videoUrl ?? body.video_url ?? "").trim();
    const userMemo = String(body.userMemo ?? body.user_memo ?? "").trim();

    const videoId = extractVideoId(videoUrl);
    if (!videoId) {
      return json({ error: "invalid_url", message: "유효하지 않은 유튜브 링크입니다." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceKey) {
      return json({ error: "supabase_not_configured" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: authData, error: authErr } = await userClient.auth.getUser();
    if (authErr || !authData?.user) {
      return json({ error: "unauthorized", message: "세션이 만료되었습니다." }, 401);
    }
    const userId = authData.user.id;

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: cached } = await admin
      .from("insight_nodes")
      .select("*")
      .eq("user_id", userId)
      .eq("video_id", videoId)
      .maybeSingle();

    if (cached && !userMemo) {
      return json({ ...cached, from_cache: true }, 200);
    }

    console.log("insight_extractor: transcript", videoId);
    const transcript = await fetchYouTubeTranscript(videoId);
    if (!transcript || transcript.length < 40) {
      return json({
        error: "no_captions",
        message: "자막(CC)이 없어 서버에서 인사이트를 만들 수 없어요.",
      }, 422);
    }

    const meta = await fetchVideoMeta(videoId);
    const title = meta?.title ?? "YouTube";
    const channelName = meta?.channel ?? "";
    const thumbnailUrl = meta?.thumb ?? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;

    console.log("insight_extractor: llm", videoId);
    const insight = await refineInsightWithLlm({
      userMemo,
      title,
      channelName,
      transcript,
    });

    const aiSummaryLines = splitSummaryLines(insight.ai_summary);
    const transcriptExcerpt = transcript.length > 4000
      ? transcript.slice(0, 4000) + "…"
      : transcript;

    const row = {
      user_id: userId,
      video_id: videoId,
      video_url: videoUrl.includes("http")
        ? videoUrl
        : `https://www.youtube.com/watch?v=${videoId}`,
      title,
      channel_name: channelName,
      thumbnail_url: thumbnailUrl,
      user_memo: userMemo,
      core_keyword: insight.core_keyword,
      ai_summary: insight.ai_summary,
      ai_summary_lines: aiSummaryLines,
      transcript_excerpt: transcriptExcerpt,
      updated_at: new Date().toISOString(),
    };

    const { data: inserted, error: dbError } = await admin
      .from("insight_nodes")
      .upsert(row, { onConflict: "user_id,video_id" })
      .select()
      .single();

    if (dbError) throw dbError;

    return json({ ...inserted, from_cache: false }, 200);
  } catch (e) {
    console.error(e);
    return json({ error: String(e?.message ?? e) }, 500);
  }
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function extractVideoId(url: string): string | null {
  const m = url.match(/(?:v=|\/)([0-9A-Za-z_-]{11})/);
  return m ? m[1] : (url.length === 11 ? url : null);
}

async function fetchVideoMeta(videoId: string): Promise<{ title: string; channel: string; thumb: string } | null> {
  try {
    const res = await fetch(
      `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`,
      { headers: { "User-Agent": "Mozilla/5.0 (compatible; Isle/1.0)" } },
    );
    if (!res.ok) return null;
    const j = await res.json();
    return {
      title: String(j.title ?? "YouTube"),
      channel: String(j.author_name ?? ""),
      thumb: String(j.thumbnail_url ?? ""),
    };
  } catch {
    return null;
  }
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
        return text.length > MAX_TRANSCRIPT ? text.slice(0, MAX_TRANSCRIPT) + "…" : text;
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

async function refineInsightWithLlm(opts: {
  userMemo: string;
  title: string;
  channelName: string;
  transcript: string;
}): Promise<{ core_keyword: string; ai_summary: string }> {
  const system = `You are a knowledge curator for a "Living Identity" portfolio app.
Output ONLY valid JSON with keys:
- core_keyword: one short Korean hashtag-style keyword (include #)
- ai_summary: exactly 3 lines of Korean expert insight, separated by newline characters, grounded in the transcript and user memo`;

  const user = `[유저 메모]: ${opts.userMemo || "(없음)"}
[제목]: ${opts.title}
[채널]: ${opts.channelName}

[스크립트]:
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
        max_tokens: 800,
        system,
        messages: [{ role: "user", content: user }],
      }),
    });
    if (!res.ok) throw new Error(`anthropic ${res.status}`);
    const data = await res.json();
    const text = data.content?.[0]?.text ?? "";
    return parseInsightJson(text);
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
      max_tokens: 800,
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
  return parseInsightJson(text);
}

function parseInsightJson(text: string): { core_keyword: string; ai_summary: string } {
  let raw = text.trim();
  const fence = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) raw = fence[1].trim();
  const map = JSON.parse(raw);
  const core = String(map.core_keyword ?? map.coreKeyword ?? "#인사이트").trim();
  const summary = String(map.ai_summary ?? map.aiSummary ?? "").trim();
  return {
    core_keyword: core.startsWith("#") ? core : `#${core}`,
    ai_summary: summary || "영상 핵심을 메모에 담아 보세요.",
  };
}

function splitSummaryLines(aiSummary: string): string[] {
  const lines = aiSummary
    .split(/\n+/)
    .map((s) => s.replace(/^[·\-\d.]+\s*/, "").trim())
    .filter((s) => s.length > 0);
  return lines.length > 0 ? lines.slice(0, 5) : [aiSummary.trim()];
}
