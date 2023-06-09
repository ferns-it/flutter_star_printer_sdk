package com.example.flutter_star_printer_sdk.Adapter

import android.content.Context
import com.starmicronics.stario10.*
import com.starmicronics.stario10.starxpandcommand.StarXpandCommandBuilder
import io.flutter.Log
import kotlinx.coroutines.*

class StarPrinterAdapter(private val mContext: Context) {

    private val LOG_TAG = "Flutter Star SDK"

    private var _manager: StarDeviceDiscoveryManager? = null


    fun createPrinterInstance(
        connectionSettings: StarConnectionSettings,
        context: Context
    ): StarPrinter = StarPrinter(connectionSettings, context)

    fun discoverPrinter(
        interfaceTypes: List<InterfaceType>,
        onPrinterFound: ((printer: StarPrinter) -> Unit),
        onDiscoveryFinished: () -> Unit
    ) {
        try {
            this._manager?.stopDiscovery()
            _manager = StarDeviceDiscoveryManagerFactory.create(
                interfaceTypes, mContext
            )

            _manager?.discoveryTime = 10000
            _manager?.callback = object : StarDeviceDiscoveryManager.Callback {
                override fun onPrinterFound(printer: StarPrinter) {
                    Log.d(LOG_TAG, "Found printer: ${printer.information?.model?.name}.")
                    onPrinterFound.invoke(printer)
                }

                override fun onDiscoveryFinished() {
                    Log.d(LOG_TAG, "Discovery Finished.")
                    onDiscoveryFinished.invoke()
                }
            }

            _manager?.startDiscovery()

        } catch (e: StarIO10IllegalHostDeviceStateException) {
            Log.d(LOG_TAG, "Star Error: $e")
        } catch (e: Exception) {
            Log.d(LOG_TAG, "Error: $e")
        }
    }

    suspend fun connectPrinter(printer: StarPrinter): Map<String, Any?> {
        return try {
            printer.openAsync().await()
            mapOf("error" to null, "connected" to true)
        } catch (e: StarIO10InvalidOperationException) {
            mapOf("error" to "Printer is already connected or opened", "connected" to false)
        } catch (e: StarIO10CommunicationException) {
            mapOf("error" to "Printer communication failed", "connected" to false)
        } catch (e: StarIO10InUseException) {
            mapOf("error" to "Printer already in use", "connected" to false)
        } catch (e: StarIO10NotFoundException) {
            mapOf("error" to "Printer not found", "connected" to false)
        } catch (e: StarIO10ArgumentException) {
            mapOf("error" to "The format of the identifier is invalid.", "connected" to false)
        } catch (e: StarIO10BadResponseException) {
            mapOf("error" to "The response from the device is invalid.", "connected" to false)
        } catch (e: StarIO10IllegalHostDeviceStateException) {
            mapOf(
                "error" to "The network function of the host device cannot be used.",
                "connected" to false
            )
        } catch (e: StarIO10UnsupportedModelException) {
            mapOf("error" to "This printer model is not supported.", "connected" to false)
        } catch (e: Exception) {
            mapOf("error" to e.localizedMessage, "connected" to false)
        }
    }


    suspend fun disconnectPrinter(printer: StarPrinter): Map<String, Any?> {
        return try {
            printer.closeAsync().await()
            mapOf("error" to null, "disconnected" to true)
        } catch (e: Exception) {
            mapOf("error" to e.localizedMessage, "disconnected" to false)
        }
    }

    fun printDocument(printer: StarPrinter, builder: StarXpandCommandBuilder) {
        try {
            val commands = builder.getCommands();
            val job = SupervisorJob()
            val scope = CoroutineScope(Dispatchers.Default + job)
            scope.launch {
                try {
                    val response = connectPrinter(printer);
                    Log.i(LOG_TAG, response.toString())
                    printer!!.printAsync(commands).await()
                } finally {
                    val response = disconnectPrinter(printer);
                    Log.i(LOG_TAG, response.toString())
                }
            }

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Error: $e")
        }
    }
}