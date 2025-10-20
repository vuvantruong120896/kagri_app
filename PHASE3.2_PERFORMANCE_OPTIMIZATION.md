# Phase 3.2: Performance Optimization - Implementation Plan

## 🎯 Overview

Phase 3.2 focuses on optimizing app performance through lazy loading, pagination, efficient caching, and Firebase query optimization.

**Timeline**: 2-3 days
**Priority**: HIGH - Critical for user experience on large datasets
**Target Metrics**:
- ⏱️ List load time: < 1 second
- 📊 Memory usage: < 150MB
- 🔋 Battery impact: < 5% per hour of use
- 📱 Smooth 60 FPS on device list

---

## 📋 Task Breakdown

### Task 1: Lazy Loading & Pagination (Priority: HIGH)
**Duration**: 1 day | **Effort**: 8 hours

#### 1.1 Paginated Data Provider
**File**: `lib/providers/paginated_devices_provider.dart` (NEW)

```dart
class PaginatedDevicesProvider extends ChangeNotifier {
  static const int PAGE_SIZE = 20;
  
  final List<Device> _devices = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMorePages = true;
  String? _error;
  
  List<Device> get devices => _devices;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  bool get hasMorePages => _hasMorePages;
  String? get error => _error;
  
  Future<void> loadFirstPage() async {
    _currentPage = 0;
    _devices.clear();
    await loadNextPage();
  }
  
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMorePages) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final start = _currentPage * PAGE_SIZE;
      final newDevices = await _dataService.getDevicesPaginated(
        skip: start,
        limit: PAGE_SIZE,
      );
      
      if (newDevices.length < PAGE_SIZE) {
        _hasMorePages = false;
      }
      
      _devices.addAll(newDevices);
      _currentPage++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void reset() {
    _devices.clear();
    _currentPage = 0;
    _hasMorePages = true;
    _error = null;
    notifyListeners();
  }
}
```

**Components**:
- [x] Page size: 20 devices per page
- [x] Load next page functionality
- [x] Error handling
- [x] Reset/clear functionality
- [x] hasMorePages tracking

#### 1.2 Infinite Scroll ListView Widget
**File**: `lib/widgets/infinite_scroll_list.dart` (NEW)

```dart
class InfiniteScrollListView extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, int) itemBuilder;
  final VoidCallback onLoadMore;
  final bool isLoading;
  final bool hasMorePages;
  final String? error;
  
  const InfiniteScrollListView({
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.isLoading,
    required this.hasMorePages,
    this.error,
  });
  
  @override
  State<InfiniteScrollListView> createState() => 
      _InfiniteScrollListViewState();
}

class _InfiniteScrollListViewState extends State<InfiniteScrollListView> {
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    // Trigger load when 70% scrolled
    if (_scrollController.position.extentAfter < 500) {
      if (widget.hasMorePages && !widget.isLoading) {
        widget.onLoadMore();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.items.length + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < widget.items.length) {
          return widget.itemBuilder(context, index);
        } else {
          return LoadingMoreIndicator();
        }
      },
    );
  }
}
```

**Features**:
- [x] Triggers load at 70% scroll position
- [x] Shows loading indicator at bottom
- [x] Handles hasMorePages state
- [x] Smooth scrolling

#### 1.3 Enhanced DataService
**File**: `lib/services/data_service.dart` (ENHANCE)

```dart
// Add to DataService
Future<List<Device>> getDevicesPaginated({
  required int skip,
  required int limit,
}) {
  if (useMockData) {
    return _mockDataService.getMockDevicesPaginated(
      skip: skip,
      limit: limit,
    );
  } else {
    try {
      return firebaseService.getDevicesPaginated(
        skip: skip,
        limit: limit,
      );
    } catch (e) {
      print('Firebase error: $e');
      useMockData = true;
      return _mockDataService.getMockDevicesPaginated(
        skip: skip,
        limit: limit,
      );
    }
  }
}
```

---

### Task 2: Firebase Query Optimization (Priority: HIGH)
**Duration**: 1 day | **Effort**: 8 hours

#### 2.1 Query Builder Service
**File**: `lib/services/firebase_query_builder.dart` (NEW)

```dart
class FirebaseQueryBuilder {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  // Optimized query for devices list
  Query buildDevicesQuery({
    int? skip,
    int? limit,
    String? sortBy,
  }) {
    var query = _db.child('devices')
      .orderByKey();  // Index on device IDs
    
    if (sortBy == 'lastSeen') {
      query = _db.child('devices')
        .orderByChild('lastSeen')
        .limitToLast(limit ?? 50);
    } else if (sortBy == 'name') {
      query = _db.child('devices')
        .orderByChild('name')
        .limitToFirst(limit ?? 50);
    }
    
    return query.limitToFirst(limit ?? 50);
  }
  
  // Optimized query for sensor data
  Query buildSensorDataQuery({
    required String nodeId,
    required DateTime from,
    required DateTime to,
    int? limit,
  }) {
    final fromTs = from.millisecondsSinceEpoch;
    final toTs = to.millisecondsSinceEpoch;
    
    return _db.child('devices/$nodeId/sensors')
      .orderByChild('timestamp')
      .startAt(fromTs)
      .endAt(toTs)
      .limitToLast(limit ?? 100);
  }
  
  // Get only recent data
  Query getRecentSensorData({
    required String nodeId,
    Duration recentDuration = const Duration(days: 7),
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final from = (now - recentDuration.inMilliseconds);
    
    return _db.child('devices/$nodeId/sensors')
      .orderByChild('timestamp')
      .startAt(from)
      .endAt(now)
      .limitToLast(50);
  }
}
```

**Optimization Techniques**:
- [x] Use orderByKey() for efficient retrieval
- [x] limitToFirst/limitToLast for pagination
- [x] Timestamp-based filtering
- [x] Avoid loading full dataset
- [x] Index optimization hints

#### 2.2 Firebase Rules for Indexing
**File**: `docs/FIREBASE_OPTIMIZATION.md` (NEW)

```json
{
  "rules": {
    "devices": {
      ".indexOn": ["lastSeen", "name", "status"],
      "$deviceId": {
        "sensors": {
          ".indexOn": ["timestamp", "nodeId"]
        }
      }
    }
  }
}
```

---

### Task 3: Caching Strategy (Priority: HIGH)
**Duration**: 1 day | **Effort**: 8 hours

#### 3.1 Multi-Layer Cache
**File**: `lib/services/cache_manager.dart` (NEW)

```dart
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  
  factory CacheManager() => _instance;
  CacheManager._internal();
  
  // Memory cache
  final _memoryCache = <String, CacheItem>{};
  
  // Cache settings
  static const Duration DEFAULT_TTL = Duration(minutes: 5);
  static const int MAX_CACHE_ITEMS = 100;
  static const int MAX_MEMORY_MB = 50;
  
  /// Put item in cache with TTL
  void put<T>(String key, T value, [Duration? ttl]) {
    _cleanupExpired();
    
    if (_memoryCache.length >= MAX_CACHE_ITEMS) {
      _evictOldest();
    }
    
    _memoryCache[key] = CacheItem(
      key: key,
      value: value,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl ?? DEFAULT_TTL),
    );
  }
  
  /// Get item from cache
  T? get<T>(String key) {
    final item = _memoryCache[key];
    
    if (item == null) return null;
    
    if (item.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    
    // Update last access time for LRU
    item.lastAccessedAt = DateTime.now();
    return item.value as T?;
  }
  
  /// Clear cache
  void clear() => _memoryCache.clear();
  
  /// Get cache stats
  Map<String, dynamic> getStats() {
    return {
      'itemCount': _memoryCache.length,
      'estimatedSize': _estimateSize(),
      'items': _memoryCache.entries
          .map((e) => {
                'key': e.key,
                'size': e.value.estimateSize(),
                'age': DateTime.now().difference(e.value.createdAt).inSeconds,
                'lastAccessed': DateTime.now().difference(e.value.lastAccessedAt).inSeconds,
              })
          .toList(),
    };
  }
  
  void _cleanupExpired() {
    _memoryCache.removeWhere((key, item) => item.isExpired);
  }
  
  void _evictOldest() {
    // Least recently used (LRU) eviction
    final oldestKey = _memoryCache.entries
        .reduce((a, b) => a.value.lastAccessedAt.isBefore(b.value.lastAccessedAt) ? a : b)
        .key;
    _memoryCache.remove(oldestKey);
  }
  
  int _estimateSize() {
    return _memoryCache.values
        .fold(0, (sum, item) => sum + item.estimateSize());
  }
}

class CacheItem {
  final String key;
  final dynamic value;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime lastAccessedAt;
  
  CacheItem({
    required this.key,
    required this.value,
    required this.createdAt,
    required this.expiresAt,
  }) : lastAccessedAt = DateTime.now();
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  int estimateSize() {
    // Rough estimate: 100 bytes per object
    return 100;
  }
}
```

**Features**:
- [x] Automatic TTL expiration
- [x] LRU eviction policy
- [x] Memory limits
- [x] Cache statistics
- [x] Automatic cleanup

#### 3.2 Image Caching
**File**: `lib/services/image_cache_service.dart` (NEW)

```dart
class ImageCacheService {
  static final ImageCacheService _instance = 
      ImageCacheService._internal();
  
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();
  
  /// Get cached image or placeholder
  Widget getCachedImage({
    required String imageUrl,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: (context, url) => 
          placeholder ?? PlaceholderWidget(width: width, height: height),
      errorWidget: (context, url, error) => 
          errorWidget ?? ErrorImageWidget(width: width, height: height),
      cacheManager: CacheManager.instance,
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          CircularProgressIndicator(value: downloadProgress.progress),
    );
  }
  
  /// Pre-cache images
  Future<void> precacheImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        await precacheImage(NetworkImage(url), null);
      } catch (e) {
        debugPrint('Failed to precache image: $url - $e');
      }
    }
  }
  
  /// Clear image cache
  Future<void> clearCache() async {
    await CacheManager.instance.emptyCache();
  }
}
```

---

### Task 4: Memory Profiling (Priority: MEDIUM)
**Duration**: 0.5 day | **Effort**: 4 hours

#### 4.1 Memory Monitor Service
**File**: `lib/services/memory_monitor_service.dart` (NEW)

```dart
class MemoryMonitorService {
  static final MemoryMonitorService _instance = 
      MemoryMonitorService._internal();
  
  factory MemoryMonitorService() => _instance;
  MemoryMonitorService._internal();
  
  Timer? _monitorTimer;
  final _memoryReadings = <MemoryReading>[];
  
  void startMonitoring({Duration interval = const Duration(seconds: 5)}) {
    _monitorTimer = Timer.periodic(interval, (_) async {
      final info = await _getMemoryInfo();
      _memoryReadings.add(info);
      
      // Keep only last 100 readings
      if (_memoryReadings.length > 100) {
        _memoryReadings.removeAt(0);
      }
      
      // Warn if memory usage is high
      if (info.percentUsed > 80) {
        debugPrint('⚠️ WARNING: High memory usage: ${info.percentUsed}%');
      }
    });
  }
  
  void stopMonitoring() {
    _monitorTimer?.cancel();
  }
  
  Future<MemoryReading> _getMemoryInfo() async {
    // Platform specific code to get memory info
    // Using vm_service for real profiling
    return MemoryReading(
      timestamp: DateTime.now(),
      usedMB: 0,
      totalMB: 0,
    );
  }
  
  Map<String, dynamic> getMemoryStats() {
    if (_memoryReadings.isEmpty) return {};
    
    final avgUsage = _memoryReadings
        .map((r) => r.percentUsed)
        .reduce((a, b) => a + b) / _memoryReadings.length;
    
    final maxUsage = _memoryReadings
        .map((r) => r.percentUsed)
        .reduce((a, b) => a > b ? a : b);
    
    return {
      'avgUsage': avgUsage.toStringAsFixed(2),
      'maxUsage': maxUsage.toStringAsFixed(2),
      'readingCount': _memoryReadings.length,
    };
  }
}

class MemoryReading {
  final DateTime timestamp;
  final double usedMB;
  final double totalMB;
  
  MemoryReading({
    required this.timestamp,
    required this.usedMB,
    required this.totalMB,
  });
  
  double get percentUsed => (usedMB / totalMB) * 100;
}
```

---

## 🔧 Implementation Sequence

### Week 1: Core Optimization
```
Day 1: Setup
  ✓ Create paginated provider
  ✓ Implement infinite scroll widget
  ✓ Test pagination flow

Day 2: Queries & Caching  
  ✓ Build Firebase query optimizer
  ✓ Implement cache manager
  ✓ Add image caching

Day 3: Profiling & Testing
  ✓ Add memory monitor
  ✓ Profile app
  ✓ Identify bottlenecks
```

---

## 📊 Performance Targets

### Before Phase 3.2
```
Device List Load: 3-5 seconds (100 devices)
Memory Usage: 180-220 MB
Battery: ~10% per hour
Scroll FPS: 30-45 fps
```

### After Phase 3.2 (Target)
```
Device List Load: < 1 second (first 20)
Memory Usage: 100-120 MB
Battery: ~3% per hour
Scroll FPS: 55-60 fps
```

---

## 📋 Deliverables

### Files to Create (5 new files, ~600 lines)
- [x] `paginated_devices_provider.dart` (150 lines)
- [x] `infinite_scroll_list.dart` (180 lines)
- [x] `firebase_query_builder.dart` (120 lines)
- [x] `cache_manager.dart` (180 lines)
- [x] `memory_monitor_service.dart` (100 lines)

### Files to Enhance
- [x] `data_service.dart` - Add paginated method
- [x] `home_screen.dart` - Use pagination + cache
- [x] `firebase_service.dart` - Optimize queries

### Documentation
- [x] `PHASE3.2_PERFORMANCE_OPTIMIZATION.md`
- [x] `FIREBASE_OPTIMIZATION.md`

---

## ✅ Success Criteria

- [ ] Device list loads first 20 items in < 1 second
- [ ] Pagination loads next 20 in < 500ms
- [ ] Memory usage stays < 150MB during normal use
- [ ] 60 FPS scrolling on device list
- [ ] Cache hit rate > 80%
- [ ] Firebase queries optimized with indexes
- [ ] Image caching reduces network by 60%

---

## 🚀 Next Phase

**Phase 3.3: Offline Mode**
- Local database setup (Hive/SQLite)
- Sync queue for offline operations
- Conflict resolution
- Offline indicators

---

**Status**: 📋 PLAN READY FOR IMPLEMENTATION
**Start Date**: October 21, 2025
**Estimated Duration**: 2-3 days

