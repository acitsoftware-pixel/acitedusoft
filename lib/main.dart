import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AcitEduSoftApp());
}

class AcitEduSoftApp extends StatelessWidget {
  const AcitEduSoftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  bool _isLoading = true;
  bool _isOffline = false;

  InAppWebViewController? _webViewController;
  late PullToRefreshController _pullToRefreshController;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final String startUrl = "https://acitedusoft.com/select_school.php";

  @override
  void initState() {
    super.initState();

    _pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        await _webViewController?.reload();
      },
    );

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      if (results.contains(ConnectivityResult.none)) {
        setState(() => _isOffline = true);
      } else {
        bool reachable = await _checkSiteReachable();
        if (reachable && _isOffline) {
          setState(() => _isOffline = false);
          _webViewController?.reload();
        }
      }
    });
  }

  Future<bool> _checkSiteReachable() async {
    try {
      final result = await InternetAddress.lookup('acitedusoft.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_webViewController != null) {
          bool canGoBack = await _webViewController!.canGoBack();
          if (canGoBack) {
            _webViewController!.goBack();
            return false;
          }
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              _isOffline ? _buildOfflineScreen() : _buildWebView(),
              if (_isLoading && !_isOffline)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(startUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowFileAccess: true,
        allowContentAccess: true,
        geolocationEnabled: true,
        cacheEnabled: true,
        useOnDownloadStart: true,
        thirdPartyCookiesEnabled: true,
      ),
      pullToRefreshController: _pullToRefreshController,
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStart: (controller, url) {
        setState(() => _isLoading = true);
      },
      onLoadStop: (controller, url) async {
        setState(() => _isLoading = false);
        _pullToRefreshController.endRefreshing();
      },
      onReceivedError: (controller, request, error) async {
        final results = await Connectivity().checkConnectivity();
        if (results.contains(ConnectivityResult.none)) {
          setState(() => _isOffline = true);
        }
      },
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      },
    );
  }

  Widget _buildOfflineScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            "No Internet Connection",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              bool reachable = await _checkSiteReachable();
              if (!mounted) return;

              if (reachable) {
                setState(() => _isOffline = false);
                _webViewController?.reload();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
