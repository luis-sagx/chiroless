package com.example.financial_control

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Widget de pantalla de inicio con botones "+ Gasto" / "+ Ingreso".
 * Abre MainActivity con el mismo extra que usan los accesos directos de
 * quick_actions, así ShortcutService recibe el tipo sin código Dart extra.
 */
class QuickAddWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
            setOnClickPendingIntent(R.id.widget_add_expense, launch(context, "add_expense", 0))
            setOnClickPendingIntent(R.id.widget_add_income, launch(context, "add_income", 1))
        }
        manager.updateAppWidget(ids, views)
    }

    private fun launch(context: Context, type: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction("quick_add.$type")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            // ponytail: clave interna de quick_actions_android (QuickActions.EXTRA_ACTION);
            // si el plugin la cambia, el widget solo abre la app sin el formulario.
            .putExtra("some unique action key", type)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
