package com.github.wgh136.venera

import android.app.Instrumentation
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResult
import androidx.activity.result.contract.ActivityResultContracts

class DirectoryPickerActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        resultLauncher.launch(intent)
    }

    private val resultLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result: ActivityResult ->
        val returnIntent = Intent()
        if (result.resultCode == RESULT_OK) {
            val uri: Uri? = result.data?.data
            if (uri != null) {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                returnIntent.putExtra("directoryUri", uri.toString())
            }
        }
        setResult(RESULT_OK, returnIntent)
        finish()
    }
}