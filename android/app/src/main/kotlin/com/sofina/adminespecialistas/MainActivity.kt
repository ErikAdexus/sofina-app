package com.sofina.adminespecialistas

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalDeNotificaciones()
    }

    // Desde Android 8 (API 26, Oreo), toda notificación debe pertenecer a
    // un "canal" que exista de antemano en el sistema; si el canal
    // referenciado en el push (citas_sofina_channel, declarado en
    // AndroidManifest.xml) no fue creado nunca, Android descarta la
    // notificación en silencio, sin error visible. Esto la crea (o la deja
    // igual si ya existía) cada vez que se abre la app.
    private fun crearCanalDeNotificaciones() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(
                "citas_sofina_channel",
                "Actualizaciones de citas",
                NotificationManager.IMPORTANCE_HIGH
            )
            canal.description = "Avisos de citas de Sofina Admin y Especialistas"

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(canal)
        }
    }
}
