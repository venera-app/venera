package com.github.wgh136.venera

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.view.KeyEvent
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream
import java.lang.Exception

class MainActivity : FlutterActivity() {
    var volumeListen = VolumeListen()
    var listening = false

    private val pickDirectoryCode = 1

    private lateinit var result: MethodChannel.Result

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickDirectoryCode) {
            if(resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }
            val pickedDirectoryUri = data?.data
            if (pickedDirectoryUri == null) {
                result.success(null)
                return
            }
            Thread {
                try {
                    result.success(onPickedDirectory(pickedDirectoryUri))
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
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
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
        val contentResolver = context.contentResolver
        var tmp = context.cacheDir
        tmp = File(tmp, "getDirectoryPathTemp")
        tmp.mkdir()
        copyDirectory(contentResolver, uri, tmp)

        return tmp.absolutePath
    }

    private fun copyDirectory(resolver: ContentResolver, srcUri: Uri, destDir: File) {
        val src = DocumentFile.fromTreeUri(context, srcUri) ?: return
        for (file in src.listFiles()) {
            if(file.isDirectory) {
                val newDir = File(destDir, file.name!!)
                newDir.mkdir()
                copyDirectory(resolver, file.uri, newDir)
            } else {
                val newFile = File(destDir, file.name!!)
                val inputStream = resolver.openInputStream(file.uri) ?: return
                val outputStream = FileOutputStream(newFile)
                inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()
            }
        }
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

