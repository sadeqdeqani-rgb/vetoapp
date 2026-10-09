package com.veto.vetoapp

import android.content.Intent
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vetoapp/document")
            .setMethodCallHandler { call, result ->
                if (call.method != "openPdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_path", "مسیر فایل معتبر نیست.", null)
                    return@setMethodCallHandler
                }
                try {
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))
                    startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/pdf")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    })
                    result.success(null)
                } catch (exception: Exception) {
                    result.error("open_failed", exception.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vetoapp/external")
            .setMethodCallHandler { call, result ->
                if (call.method != "openUrl") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.argument<String>("url")
                if (url.isNullOrBlank() || !url.startsWith("https://t.me/")) {
                    result.error("invalid_url", "نشانی بات تلگرام معتبر نیست.", null)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)))
                    result.success(null)
                } catch (exception: Exception) {
                    result.error("open_failed", exception.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vetoapp/biometric-key")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canAuthenticate" -> result.success(
                        BiometricManager.from(this).canAuthenticate(
                            BiometricManager.Authenticators.BIOMETRIC_STRONG,
                        ) == BiometricManager.BIOMETRIC_SUCCESS,
                    )
                    "createKey" -> {
                        val alias = biometricAlias(call.argument<String>("credentialId"))
                        if (alias == null) {
                            result.error("invalid_credential", "شناسه بیومتریک معتبر نیست.", null)
                        } else {
                            try {
                                result.success(createBiometricKey(alias))
                            } catch (exception: Exception) {
                                result.error("key_creation_failed", exception.message, null)
                            }
                        }
                    }
                    "sign" -> {
                        val alias = biometricAlias(call.argument<String>("credentialId"))
                        val payload = call.argument<String>("payload")
                        if (alias == null || payload == null) {
                            result.error("invalid_request", "درخواست امضای بیومتریک معتبر نیست.", null)
                        } else {
                            signWithBiometric(alias, payload, result)
                        }
                    }
                    "deleteKey" -> {
                        val alias = biometricAlias(call.argument<String>("credentialId"))
                        if (alias == null) {
                            result.error("invalid_credential", "شناسه بیومتریک معتبر نیست.", null)
                        } else {
                            try {
                                val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                                keyStore.deleteEntry(alias)
                                result.success(null)
                            } catch (exception: Exception) {
                                result.error("key_delete_failed", exception.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun biometricAlias(credentialId: String?): String? {
        if (credentialId == null || !credentialId.matches(Regex("[0-9a-fA-F-]{36}"))) return null
        return "vetoapp_bio_${credentialId.replace("-", "").lowercase()}"
    }

    private fun createBiometricKey(alias: String): String {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        val builder = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG,
            )
        } else {
            builder.setUserAuthenticationValidityDurationSeconds(-1)
        }
        val pair = generator.apply { initialize(builder.build()) }.generateKeyPair()
        return Base64.encodeToString(pair.public.encoded, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun signWithBiometric(alias: String, payload: String, result: MethodChannel.Result) {
        try {
            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val privateKey = keyStore.getKey(alias, null) as? java.security.PrivateKey
                ?: throw IllegalStateException("کلید بیومتریک ثبت نشده است.")
            val signature = Signature.getInstance("SHA256withECDSA").apply { initSign(privateKey) }
            val prompt = BiometricPrompt(
                this,
                ContextCompat.getMainExecutor(this),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                        try {
                            val signer = authResult.cryptoObject?.signature
                                ?: throw IllegalStateException("کلید امضا آماده نیست.")
                            signer.update(payload.toByteArray(Charsets.UTF_8))
                            val signed = signer.sign()
                            result.success(Base64.encodeToString(
                                signed,
                                Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
                            ))
                        } catch (exception: Exception) {
                            result.error("signature_failed", exception.message, null)
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        result.error("biometric_auth_failed", errString.toString(), errorCode)
                    }

                    override fun onAuthenticationFailed() {
                        // The platform keeps the prompt open for another attempt.
                    }
                },
            )
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("احراز هویت بیومتریک وتواپ")
                .setSubtitle("برای امضای درخواست ورود، اثر انگشت خود را تأیید کنید.")
                .setNegativeButtonText("انصراف")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .build()
            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(signature))
        } catch (exception: Exception) {
            result.error("biometric_sign_failed", exception.message, null)
        }
    }
}
