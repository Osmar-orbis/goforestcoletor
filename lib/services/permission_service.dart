// lib/services/permission_service.dart

import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class PermissionService {
  
  /// Solicita a permissão de armazenamento de forma robusta para Android e outras plataformas.
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // No Android, a permissão para gerenciar todos os arquivos é a mais garantida
      // para salvar em locais como a pasta /Download.
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;

    } else {
      // Para iOS e outras plataformas, a permissão de storage é suficiente.
      var status = await Permission.storage.request();
      return status.isGranted;
    }
  }
}