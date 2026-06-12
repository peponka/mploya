@echo off
REM ================================================================
REM  Mploya — Build Release APK
REM  Uso: build_release.bat
REM  
REM  Requisitos previos:
REM    1. Crear keystore: keytool -genkey -v -keystore mploya-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mploya
REM    2. Crear android/key.properties con:
REM         storePassword=TU_PASSWORD
REM         keyPassword=TU_PASSWORD  
REM         keyAlias=mploya
REM         storeFile=../../mploya-release.jks
REM    3. Asegurarse de que .env tiene las variables de produccion
REM ================================================================

echo.
echo ===================================================
echo   MPLOYA — Build Release APK
echo ===================================================
echo.

REM Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ERROR: Ejecutar desde la raiz del proyecto Flutter
    exit /b 1
)

REM Verificar key.properties
if not exist "android\key.properties" (
    echo.
    echo !! FALTA android\key.properties
    echo.
    echo Crea el archivo con este contenido:
    echo   storePassword=TU_PASSWORD
    echo   keyPassword=TU_PASSWORD
    echo   keyAlias=mploya
    echo   storeFile=../../mploya-release.jks
    echo.
    exit /b 1
)

echo [1/4] Limpiando build anterior...
call flutter clean

echo [2/4] Descargando dependencias...
call flutter pub get

echo [3/4] Compilando APK release...
call flutter build apk --release --target-platform android-arm64 --dart-define-from-file=.env

echo [4/4] Verificando salida...
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo ===================================================
    echo   BUILD EXITOSO!
    echo   APK: build\app\outputs\flutter-apk\app-release.apk
    echo ===================================================
    echo.
    for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do echo   Tamanio: %%~zA bytes
    echo.
) else (
    echo.
    echo   ERROR: No se genero el APK. Revisa los errores arriba.
    echo.
    exit /b 1
)
