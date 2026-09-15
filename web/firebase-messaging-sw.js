// Dummy Service Worker to prevent Firebase Messaging from crashing on Flutter Web
self.addEventListener('push', function(event) {
  console.log('[firebase-messaging-sw.js] Received background push message.');
});
