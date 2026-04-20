package com.newyorklife.mynyl.mobile

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import androidx.compose.ui.platform.ComposeView
import androidx.core.view.WindowCompat
import androidx.fragment.app.DialogFragment
import com.salesforce.android.smi.ui.UIClient
import com.salesforce.android.smi.ui.UIConfiguration
import com.salesforce.android.smi.ui.ViewComponents
import java.lang.reflect.Proxy

/**
 * Full-screen wrapper for Salesforce chat UI so the app can expose custom
 * minimize and close controls while still using the SDK chat content.
 */
class SalesforceChatFragment : DialogFragment() {

    private var uiClient: UIClient? = null
    private var uiConfiguration: UIConfiguration? = null

    companion object {
        private var tempConfig: UIConfiguration? = null

        fun newInstance(config: UIConfiguration): SalesforceChatFragment {
            tempConfig = config
            return SalesforceChatFragment()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        uiConfiguration = tempConfig
        setStyle(STYLE_NORMAL, R.style.ChatFullScreenDialogTheme)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val rootView = inflater.inflate(R.layout.chat_activity, container, false)
        val contentContainer = rootView.findViewById<FrameLayout>(R.id.content_container)
        val minimizeButton = rootView.findViewById<ImageButton>(R.id.minimize_button)
        val closeButton = rootView.findViewById<ImageButton>(R.id.close_button)

        minimizeButton.setOnClickListener {
            SalesforceMessagingManager.sendEventToFlutter("minimized")
            dismiss()
        }

        closeButton.setOnClickListener {
            SalesforceMessagingManager.sendEventToFlutter("closed")
            dismiss()
        }

        uiConfiguration?.let { config ->
            uiClient = UIClient.Factory.create(config)
            uiClient?.viewComponents = createViewComponentsWithoutTopBar()
            val composeView = ComposeView(requireContext()).apply {
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                setContent {
                    uiClient?.MessagingInAppUI(onExit = { dismiss() })
                }
            }
            contentContainer.addView(composeView)
        } ?: dismiss()

        return rootView
    }

    private fun createViewComponentsWithoutTopBar(): ViewComponents {
        val defaultComponents = ViewComponents.Companion.Default
        return Proxy.newProxyInstance(
            ViewComponents::class.java.classLoader,
            arrayOf(ViewComponents::class.java)
        ) { proxy, method, args ->
            when (method.name) {
                "ChatTopAppBar" -> Unit
                "equals" -> proxy === args?.firstOrNull()
                "hashCode" -> System.identityHashCode(proxy)
                "toString" -> "SalesforceChatViewComponentsProxy"
                else -> method.invoke(defaultComponents, *(args ?: emptyArray()))
            }
        } as ViewComponents
    }

    override fun onStart() {
        super.onStart()
        dialog?.window?.let { window ->
            WindowCompat.setDecorFitsSystemWindows(window, true)
        }
        dialog?.window?.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        dialog?.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        uiClient = null
        tempConfig = null
    }
}
