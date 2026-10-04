package com.example.financial_control

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews

/**
 * Widget de pantalla de inicio: resumen del mes + botones "↑ Gasto" / "↓ Ingreso".
 * Los botones abren MainActivity con el mismo extra que usan los accesos directos
 * de quick_actions, así ShortcutService recibe el tipo sin código Dart extra.
 * Los datos los escribe la app vía MethodChannel "sagx/widget" (MainActivity).
 */
class QuickAddWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    companion object {
        const val PREFS = "sagx_widget"

        // Redibuja todas las instancias del widget con los datos guardados.
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, QuickAddWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val spent = prefs.getString("spent", null)
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget)

            if (spent == null) {
                // Sin datos todavía: valores por defecto del layout
                views.setViewVisibility(R.id.widget_progress_row, View.GONE)
            } else {
                views.setTextViewText(R.id.widget_title, "${prefs.getString("month", "")} · gastado")
                views.setTextViewTextSize(R.id.widget_amount, TypedValue.COMPLEX_UNIT_SP, 32f)
                if (prefs.getBoolean("hidden", false)) {
                    views.setTextViewText(R.id.widget_amount, "••••")
                    views.setViewVisibility(R.id.widget_progress_row, View.GONE)
                } else {
                    views.setTextViewText(R.id.widget_amount, spent)
                    views.setViewVisibility(R.id.widget_progress_row, View.VISIBLE)
                    val percent = prefs.getInt("percent", -1)
                    if (percent < 0) {
                        views.setViewVisibility(R.id.widget_progress, View.GONE)
                        views.setTextViewText(R.id.widget_budget, "Sin presupuesto este mes")
                    } else {
                        views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                        views.setProgressBar(R.id.widget_progress, 100, percent.coerceAtMost(100), false)
                        views.setTextViewText(R.id.widget_budget, prefs.getString("budget_line", ""))
                        if (percent >= 100) views.setTextColor(R.id.widget_budget, Color.parseColor("#F43F5E"))
                    }
                }
            }

            views.setOnClickPendingIntent(R.id.widget_summary, launch(context, null, 2))
            views.setOnClickPendingIntent(R.id.widget_add_expense, launch(context, "add_expense", 0))
            views.setOnClickPendingIntent(R.id.widget_add_income, launch(context, "add_income", 1))
            manager.updateAppWidget(ids, views)
        }

        private fun launch(context: Context, type: String?, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (type != null) {
                intent.setAction("quick_add.$type")
                // ponytail: clave interna de quick_actions_android (QuickActions.EXTRA_ACTION);
                // si el plugin la cambia, el widget solo abre la app sin el formulario.
                intent.putExtra("some unique action key", type)
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
