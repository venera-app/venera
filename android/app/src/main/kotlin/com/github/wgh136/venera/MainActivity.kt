package com.github.wgh136.venera

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.lang.Exception

class MainActivity : FlutterActivity() {
    var volumeListen = VolumeListen()
    var listening = false

    private val pickDirectoryCode = 1

    private lateinit var result: MethodChannel.Result

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickDirectoryCode && resultCode == Activity.RESULT_OK) {
            val pickedDirectoryUri = data?.getStringExtra("directoryUri")
            if (pickedDirectoryUri == null) {
                result.success(null)
            }
            val uri = Uri.parse(pickedDirectoryUri)
            Thread {
                try {
                    result.success(onPickedDirectory(uri))
                }
                catch (e: Exception) {
                    result.error("Failed to Copy Files", e.toString(), null)
                }
            }.start()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "venera/method_channel"
        ).setMethodCallHandler { call, res ->
            when (call.method) {
                "getProxy" -> res.success(getProxy())
                "setScreenOn" -> {
                    val set = call.argument<Boolean>("set") ?: false
                    if (set) {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    res.success(null)
                }
                "getDirectoryPath" -> {
                    this.result = res
                    val intent = Intent(this, DirectoryPickerActivity::class.java)
                    startActivityForResult(intent, pickDirectoryCode)
                }
                else -> res.notImplemented()
            }
        }

        val channel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "venera/volume")
        channel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    listening = true
                    volumeListen.onUp = {
                        events.success(1)
                    }
                    volumeListen.onDown = {
                        events.success(2)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    listening = false
                }
            })
    }

    private fun getProxy(): String {
        val host = System.getProperty("http.proxyHost")
        val port = System.getProperty("http.proxyPort")
        return if (host != null && port != null) {
            "$host:$port"
        } else {
            "No Proxy"
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if(listening){
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeListen.down()
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeListen.up()
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    /// copy the directory to tmp directory, return copied directory
    private fun onPickedDirectory(uri: Uri): String {
        val tempDir = File(context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS), "tempDir")
        if (!tempDir.exists()) {
            tempDir.mkdirs()
        }

        val contentResolver: ContentResolver = context.contentResolver

        val childrenUri = Uri.withAppendedPath(uri, "children")

        contentResolver.query(childrenUri, null, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val documentId = cursor.getString(cursor.getColumnIndexOrThrow("_id"))
                val fileUri = Uri.withAppendedPath(uri, documentId)

                // 复制文件
                val inputStream: InputStream? = contentResolver.openInputStream(fileUri)
                val outputStream: OutputStream = FileOutputStream(File(tempDir, documentId))

                inputStream?.use { input ->
                    outputStream.use { output ->
                        input.copyTo(output)
                    }
                }
            }
        }

        return tempDir.absolutePath
    }
}

class VolumeListen{
    var onUp = fun() {}
    var onDown = fun() {}
    fun up(){
        onUp()
    }
    fun down(){
        onDown()
    }
}

