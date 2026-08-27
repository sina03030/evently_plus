/// Requests uploads that are safe to perform while the app is running.
///
/// This is a no-op on mobile, where delivery remains owned by Workmanager. On
/// web it sends the durable queue from the active browser page.
abstract interface class RuntimeUploadScheduler {
  /// Requests an upload and completes after all currently queued requests.
  Future<void> requestUpload();

  void dispose();
}

class NoopRuntimeUploadScheduler implements RuntimeUploadScheduler {
  const NoopRuntimeUploadScheduler();

  @override
  Future<void> requestUpload() async {}

  @override
  void dispose() {}
}
