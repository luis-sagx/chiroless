package com.example.financial_control

import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var userPresentReceiverRegistered = false

    private val userPresentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent?) {
            if (intent?.action == Intent.ACTION_USER_PRESENT) {
                QuickAddWidget.refresh(context)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(userPresentReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(userPresentReceiver, filter)
        }
        userPresentReceiverRegistered = true
    }

    override fun onDestroy() {
        if (userPresentReceiverRegistered) {
            unregisterReceiver(userPresentReceiver)
            userPresentReceiverRegistered = false
        }
        super.onDestroy()
    }

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
