package com.isle.app

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.app.Activity

/// 한도 초과 개입 전면 화면
class AppLimitInterventionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val title = intent.getStringExtra("title") ?: "오늘 한도에 도달했어요"
        val body =
            intent.getStringExtra("body")
                ?: "잠시 쉬었다가 Isle에서 의도한 콘텐츠만 보세요."
        val used = intent.getIntExtra("usedMinutes", 0)
        val limit = intent.getIntExtra("limitMinutes", 0)

        val root =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#F8F9FB"))
                setPadding(48, 48, 48, 48)
            }

        root.addView(
            TextView(this).apply {
                text = title
                textSize = 22f
                setTextColor(Color.parseColor("#0B1538"))
                gravity = Gravity.CENTER
            },
        )
        root.addView(
            TextView(this).apply {
                text = body
                textSize = 16f
                setTextColor(Color.parseColor("#666666"))
                gravity = Gravity.CENTER
                setPadding(0, 24, 0, 0)
            },
        )
        if (limit > 0) {
            root.addView(
                TextView(this).apply {
                    text = "오늘 ${used}분 / 목표 ${limit}분"
                    textSize = 14f
                    setTextColor(Color.parseColor("#4A6FA5"))
                    gravity = Gravity.CENTER
                    setPadding(0, 16, 0, 0)
                },
            )
        }
        root.addView(
            Button(this).apply {
                text = "알겠어요 · 나가기"
                setOnClickListener { finish() }
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = 48 },
        )

        setContentView(root)
    }
}
