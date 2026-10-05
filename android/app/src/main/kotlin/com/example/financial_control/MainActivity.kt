package com.example.financial_control

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Puente con el widget: la app escribe el resumen y el widget lo lee.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chiroless/widget")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(QuickAddWidget.PREFS, Context.MODE_PRIVATE)
                when (call.method) {
                    "update" -> {
                        prefs.edit()
                            .putString("month", call.argument<String>("month"))
                            .putString("spent", call.argument<String>("spent"))
                            .putString("budget_line", call.argument<String>("budget_line"))
                            .putInt("percent", call.argument<Number>("percent")?.toInt() ?: -1)
                            .apply()
                        QuickAddWidget.refresh(this)
                        result.success(null)
                    }
                    "clear" -> {
                        val hidden = prefs.getBoolean("hidden", false)
                        prefs.edit().clear().putBoolean("hidden", hidden).apply()
                        QuickAddWidget.refresh(this)
                        result.success(null)
                    }
                    "setHidden" -> {
                        prefs.edit().putBoolean("hidden", call.arguments as? Boolean ?: false).apply()
                        QuickAddWidget.refresh(this)
                        result.success(null)
                    }
                    "isHidden" -> result.success(prefs.getBoolean("hidden", false))
                    else -> result.notImplemented()
                }
            }
    }
}
