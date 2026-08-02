package fr.autoclair.autoclair_app

import android.app.Activity
import android.content.Intent
import androidx.activity.result.ActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "fr.autoclair/document_scanner"
        private const val METHOD_SCAN_DOCUMENT = "scanDocument"
        private const val MAX_SCAN_PAGES = 10
        private const val CACHE_RETENTION_MILLIS =
            24L * 60L * 60L * 1000L
    }

    private var pendingScanResult: MethodChannel.Result? = null

    private val scannerLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult(),
    ) { activityResult: ActivityResult ->
        when (activityResult.resultCode) {
            Activity.RESULT_OK -> {
                handleSuccessfulScan(activityResult.data)
            }

            Activity.RESULT_CANCELED -> {
                finishScanWithSuccess(null)
            }

            else -> {
                finishScanWithError(
                    code = "SCAN_RESULT_FAILED",
                    message = "Le scanner a renvoyé un résultat inattendu.",
                )
            }
        }
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SCAN_DOCUMENT -> startDocumentScan(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startDocumentScan(
        result: MethodChannel.Result,
    ) {
        if (pendingScanResult != null) {
            result.error(
                "SCAN_IN_PROGRESS",
                "Un scan est déjà en cours.",
                null,
            )
            return
        }

        pendingScanResult = result

        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(false)
            .setPageLimit(MAX_SCAN_PAGES)
            .setResultFormats(
                GmsDocumentScannerOptions.RESULT_FORMAT_PDF,
            )
            .setScannerMode(
                GmsDocumentScannerOptions.SCANNER_MODE_FULL,
            )
            .build()

        val scanner = GmsDocumentScanning.getClient(options)

        scanner.getStartScanIntent(this)
            .addOnSuccessListener { intentSender ->
                scannerLauncher.launch(
                    IntentSenderRequest
                        .Builder(intentSender)
                        .build(),
                )
            }
            .addOnFailureListener { error ->
                val unsupported =
                    error is MlKitException &&
                        error.errorCode == MlKitException.UNSUPPORTED

                val code = if (unsupported) {
                    "SCANNER_UNSUPPORTED"
                } else {
                    "SCANNER_START_FAILED"
                }

                val message = if (unsupported) {
                    "Le scanner de documents n'est pas compatible avec cet appareil."
                } else {
                    error.message
                        ?: "Le scanner de documents n'a pas pu démarrer."
                }

                finishScanWithError(
                    code = code,
                    message = message,
                )
            }
    }

    private fun handleSuccessfulScan(
        data: Intent?,
    ) {
        val scanResult = data?.let {
            GmsDocumentScanningResult
                .fromActivityResultIntent(it)
        }

        val pdf = scanResult?.pdf

        if (pdf == null) {
            finishScanWithError(
                code = "PDF_UNAVAILABLE",
                message = "Le scanner n'a produit aucun fichier PDF.",
            )
            return
        }

        val callback = pendingScanResult ?: return

        Thread {
            try {
                val outputFile = copyPdfToCache(pdf.uri)
                val response = mapOf(
                    "path" to outputFile.absolutePath,
                    "name" to outputFile.name,
                    "size" to outputFile.length(),
                    "pageCount" to pdf.pageCount,
                )

                runOnUiThread {
                    if (pendingScanResult === callback) {
                        pendingScanResult = null
                        callback.success(response)
                    }
                }
            } catch (error: Exception) {
                runOnUiThread {
                    if (pendingScanResult === callback) {
                        pendingScanResult = null
                        callback.error(
                            "SCAN_FILE_FAILED",
                            error.message
                                ?: "Le PDF numérisé n'a pas pu être préparé.",
                            null,
                        )
                    }
                }
            }
        }.start()
    }

    private fun copyPdfToCache(
        sourceUri: android.net.Uri,
    ): File {
        val scanDirectory = File(
            cacheDir,
            "autoclair_document_scans",
        )

        if (
            !scanDirectory.exists() &&
            !scanDirectory.mkdirs()
        ) {
            throw IllegalStateException(
                "Le dossier temporaire du scanner n'a pas pu être créé.",
            )
        }

        cleanExpiredScans(scanDirectory)

        val outputFile = File(
            scanDirectory,
            "autoclair_scan_${System.currentTimeMillis()}.pdf",
        )

        val inputStream =
            contentResolver.openInputStream(sourceUri)
                ?: throw IllegalStateException(
                    "Le PDF numérisé n'a pas pu être ouvert.",
                )

        inputStream.use { input ->
            outputFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        if (
            !outputFile.exists() ||
            outputFile.length() == 0L
        ) {
            outputFile.delete()
            throw IllegalStateException(
                "Le PDF numérisé est vide.",
            )
        }

        return outputFile
    }

    private fun cleanExpiredScans(
        directory: File,
    ) {
        val expirationThreshold =
            System.currentTimeMillis() -
                CACHE_RETENTION_MILLIS

        directory.listFiles()?.forEach { file ->
            if (
                file.isFile &&
                file.lastModified() < expirationThreshold
            ) {
                file.delete()
            }
        }
    }

    private fun finishScanWithSuccess(
        value: Any?,
    ) {
        val result = pendingScanResult ?: return
        pendingScanResult = null
        result.success(value)
    }

    private fun finishScanWithError(
        code: String,
        message: String,
    ) {
        val result = pendingScanResult ?: return
        pendingScanResult = null
        result.error(code, message, null)
    }
}
