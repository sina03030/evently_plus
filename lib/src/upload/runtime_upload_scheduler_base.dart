/// Requests uploads that are safe to perform while the app is running.
///
/// This is a no-op on mobile, where delivery remains owned by Workmanager. On
/// web it sends the durable queue from the active browser page.
abstract interface class RuntimeUploadScheduler {
  void requestUpload();

  void dispose();
}

class NoopRuntimeUploadScheduler implements RuntimeUploadScheduler {
  const NoopRuntimeUploadScheduler();

  @override
  void requestUpload() {}

  @override
  void dispose() {}
}
