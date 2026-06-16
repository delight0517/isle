package com.isle.app

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/// 차단된 앱 진입 시 표시되는 전면 안내 화면.
class BlockOverlayActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val label = runCatching {
            val pkg = intent.getStringExtra(EXTRA_PACKAGE) ?: return@runCatching null
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        }.getOrNull()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0B1538"))
            setPadding(64, 64, 64, 64)
        }

        root.addView(
            TextView(this).apply {
                text = if (label != null) "$label 은(는) 지금 차단했어요" else "이 앱은 지금 차단했어요"
                textSize = 22f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
            },
        )
        root.addView(
            TextView(this).apply {
                text = "Isle에서 의도한 콘텐츠에 집중해 보세요."
                textSize = 16f
                setTextColor(Color.parseColor("#9FB3D8"))
                gravity = Gravity.CENTER
                setPadding(0, 24, 0, 0)
            },
        )
        root.addView(
            Button(this).apply {
                text = "홈으로"
                setOnClickListener { goHome() }
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = 48 },
        )

        setContentView(root)
    }

    override fun onBackPressed() {
        goHome()
    }

    private fun goHome() {
        val home = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(home)
        finish()
    }

    companion object {
        const val EXTRA_PACKAGE = "blockedPackage"
    }
}
