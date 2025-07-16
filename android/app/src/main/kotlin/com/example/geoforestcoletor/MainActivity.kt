// Arquivo: android/app/src/main/kotlin/com/example/geoforestcoletor/MainActivity.kt

package com.example.geoforestcoletor

// 1. MUDE O IMPORT DE FlutterActivity PARA FlutterFragmentActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import com.google.firebase.FirebaseApp
import com.google.firebase.perf.FirebasePerformance

// 2. MUDE A HERANÇA DA CLASSE AQUI
class MainActivity: FlutterFragmentActivity() {
    // O corpo da classe com a inicialização do Firebase permanece o mesmo.
    // Ele já está correto.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        FirebaseApp.initializeApp(this)
        
        FirebasePerformance.getInstance().isPerformanceCollectionEnabled = true
    }
}
