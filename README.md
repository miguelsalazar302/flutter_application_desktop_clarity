# Demo desktop

Aplicación de escritorio desarrollada en **Flutter** y empaquetada para Windows usando **Inno Setup**
y con la configuracion para subir a las tiendas en AppStore para MAC

---

## 📦 Compilación y empaquetado

### 1. Compilar para Windows en modo release
```bash
flutter build windows --release
```

### 2. Crear el empaquetado
```bash
C:\"Program Files (x86)"\"Inno Setup 6"\ISCC .\installer-config.iss
```

### 3. Firmar el empaquetado
```bash
signtool sign /f "C:\wamp64\www\flutter\application_desktop_ble\certificado.pfx" /p deepsea /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "C:\wamp64\www\flutter\application_desktop_ble\Output\Demo desktop-v1.0.1Installer-64.exe"
```

## 🛠️ Archivos modificados
Durante el proceso de personalización de la aplicación se modificaron los siguientes archivos:

### 1. windows/runner/main.cpp
Se cambió el título de la ventana principal en la línea 30:

```cpp
if (!window.Create(L"Demo desktop", origin, size)) {
    return EXIT_FAILURE;
}
```

### 2. windows/runner/Runner.rc
Se actualizaron los metadatos del ejecutable:

```rc
VALUE "CompanyName", "Deepseadev" "\0"
VALUE "FileDescription", "Demo desktop - Deepseadev" "\0"
VALUE "FileVersion", VERSION_AS_STRING "\0"
VALUE "InternalName", "Demo desktop" "\0"
VALUE "LegalCopyright", "Copyright © 2025 Deepseadev. All rights reserved." "\0"
VALUE "OriginalFilename", "application_desktop_ble.exe" "\0"
VALUE "ProductName", "Demo desktop" "\0"
VALUE "ProductVersion", VERSION_AS_STRING "\0"
```

### 3. macos/Runner/Configs/AppInfo.xcconfig
Se ajustó la configuración de la app para macOS:

```xcconfig
// The application's name. By default this is also the title of the Flutter window.
PRODUCT_NAME = Demo desktop

// The application's bundle identifier
PRODUCT_BUNDLE_IDENTIFIER = com.deepseadev.desktop

// The copyright displayed in application information
PRODUCT_COPYRIGHT = Copyright © 2025 Deepseadev. All rights reserved.
```

## 📝 Notas Windows
El instalador se genera usando el script installer-config.iss, el cual está preparado para copiar todos los archivos de la carpeta `build/windows/x64/runner/Release`.

Se configuró el ícono y la visualización correcta en Agregar o quitar programas de Windows.

Al desinstalar se eliminan automáticamente la carpeta de instalación y los accesos directos creados (escritorio y menú inicio).

## Comandos para crear el certificado para windows
### 1. Generar una clave privada.
```bash
openssl genrsa -out DemoDesktopKey.key 2048
```

### 2. Generar un archivo CSR con la ayuda de la clave privada.
```bash
openssl req -new -key DemoDesktopKey.key -out DemoDesktopCsr.csr
```
clave:deepsea

### 3.  Genere un archivo CRT con la ayuda de la clave privada y el archivo CSR.
```bash
openssl x509 -in DemoDesktopCsr.csr -out DemoDesktopCsr.crt -req -signkey DemoDesktopKey.key -days 365
```

### 4. Genere el archivo .pfx (finalmente) con la ayuda de la clave privada y el archivo CRT.
```bash
openssl pkcs12 -export -out CERTIFICADO.pfx -inkey DemoDesktopKey.key -in DemoDesktopCsr.crt
```