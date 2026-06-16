package com.isle.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView

/// 설치된 실행 가능 앱 다중 선택 — iOS FamilyActivityPicker 의 Android 대체.
/// 결과는 패키지명 CSV([EXTRA_RESULT]) + 개수([EXTRA_COUNT]) 로 반환.
class AppPickerActivity : Activity() {
    private val packages = mutableListOf<String>()
    private lateinit var listView: ListView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val existing = (intent.getStringExtra(EXTRA_EXISTING) ?: "")
            .split(',').map { it.trim() }.filter { it.isNotEmpty() }.toSet()

        val apps = loadLaunchableApps()
        val labels = apps.map { it.second }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
        }

        root.addView(
            TextView(this).apply {
                text = "차단할 앱 선택"
                textSize = 20f
                setTextColor(Color.parseColor("#0B1538"))
                setPadding(48, 48, 48, 24)
            },
        )

        listView = ListView(this).apply {
            choiceMode = ListView.CHOICE_MODE_MULTIPLE
            adapter = ArrayAdapter(
                this@AppPickerActivity,
                android.R.layout.simple_list_item_multiple_choice,
                labels,
            )
        }
        root.addView(
            listView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
            ).apply { weight = 1f },
        )

        packages.addAll(apps.map { it.first })
        for (i in packages.indices) {
            if (existing.contains(packages[i])) listView.setItemChecked(i, true)
        }

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(48, 24, 48, 48)
        }
        buttonRow.addView(
            Button(this).apply {
                text = "취소"
                setOnClickListener {
                    setResult(Activity.RESULT_CANCELED)
                    finish()
                }
            },
        )
        buttonRow.addView(
            Button(this).apply {
                text = "확인"
                setOnClickListener { confirm() }
            },
        )
        root.addView(buttonRow)

        setContentView(root)
    }

    private fun confirm() {
        val checked = listView.checkedItemPositions
        val selected = mutableListOf<String>()
        for (i in packages.indices) {
            if (checked.get(i, false)) selected.add(packages[i])
        }
        val data = Intent().apply {
            putExtra(EXTRA_RESULT, selected.joinToString(","))
            putExtra(EXTRA_COUNT, selected.size)
        }
        setResult(Activity.RESULT_OK, data)
        finish()
    }

    /// (packageName, label) — 런처에 표시되는 앱만, 자기 자신 제외, 라벨순 정렬.
    private fun loadLaunchableApps(): List<Pair<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(intent, 0)
        return resolved
            .mapNotNull { ri ->
                val pkg = ri.activityInfo?.packageName ?: return@mapNotNull null
                if (pkg == packageName) return@mapNotNull null
                val label = ri.loadLabel(pm).toString()
                pkg to label
            }
            .distinctBy { it.first }
            .sortedBy { it.second.lowercase() }
    }

    companion object {
        const val EXTRA_EXISTING = "existing"
        const val EXTRA_RESULT = "result"
        const val EXTRA_COUNT = "count"
    }
}
