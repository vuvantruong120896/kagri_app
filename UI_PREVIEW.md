# 📱 Preview Screenshots - Soil Metrics Display

## 🏠 Home Screen View

```
┌─────────────────────────────────────────┐
│  KAGRI                    🔔 ➕ 👤 🔄   │
├─────────────────────────────────────────┤
│  Thiết bị: [Tất cả thiết bị ▼]          │
├─────────────────────────────────────────┤
│                                          │
│  📊 Tổng số Node: 5    📶 Trạng thái:   │
│     Online: 3                Hoạt động   │
│                          3/5 online      │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ 🌾 Sensor Ruộng A (0xCC64) ┃Online │ │
│ │ Node: 0xCC64            Lần cuối 2s │ │
│ ├─────────────────────────────────────┤ │
│ │ ┌──────────┬──────────┐             │ │
│ │ │ 💧 Độ ẩm │ 🌡️Nhiệt độ│             │ │
│ │ │  đất    │   đất     │             │ │
│ │ │ 55.2%   │  23.5°C   │             │ │
│ │ │ Tối ưu  │  Tối ưu   │             │ │
│ │ └──────────┴──────────┘             │ │
│ │ ┌──────────┬──────────┐             │ │
│ │ │ 🔬 pH   │ ⚡ EC     │             │ │
│ │ │ 6.8     │ 2.1 mS/cm │             │ │
│ │ │ Tối ưu  │ Tối ưu    │             │ │
│ │ └──────────┴──────────┘             │ │
│ │ ┌─────────┬─────────┬─────────┐    │ │
│ │ │ 🌿 N    │ 🌸 P    │ 🌾 K    │    │ │
│ │ │ 120mg/kg│ 55mg/kg │175mg/kg │    │ │
│ │ │ Tối ưu  │ Tối ưu  │ Tối ưu  │    │ │
│ │ └─────────┴─────────┴─────────┘    │ │
│ │                                     │ │
│ │ 🔋 Pin: 3.85V (95%) 📶 RSSI: -65dBm│ │
│ │ Counter: 142      08:45:23          │ │
│ └─────────────────────────────────────┘ │
│                                          │
│ ┌─────────────────────────────────────┐ │
│ │ 🌡️ Sensor Nhà Kính (0xAB12) Offline││
│ │ Lần cuối: 5 phút trước               │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Màu sắc:**
- Các card có viền và nền màu tương ứng:
  - 🟢 Xanh lá: Giá trị tối ưu
  - 🟠 Cam: Cảnh báo
  - 🔴 Đỏ: Nguy hiểm

---

## 📋 Device Details Dialog - Full View

```
┌─────────────────────────────────────────┐
│  🌾 Sensor Ruộng A (Node: 0xCC64)    ✕ │
├─────────────────────────────────────────┤
│  Thông tin Node                          │
│  ┌─────────────────────────────────────┐│
│  │ Loại: sensor                        ││
│  │ Trạng thái: 🟢 Online               ││
│  │ Lần cuối: 2 giây trước              ││
│  │ Tạo lúc: 15/10/2025 14:30          ││
│  └─────────────────────────────────────┘│
│                                          │
│  Lịch sử dữ liệu          15 bản ghi   │
│  ┌─────────────────────────────────────┐│
│  │ 🆕 20/10 08:45:23        [MỚI NHẤT]││
│  │ Counter: 142 | Temp: 23.5°C | ...  ││
│  │ ▼                                   ││
│  │ ┌─────────────────────────────────┐││
│  │ │ ┌─────────────────────────────┐│││
│  │ │ │ 💧 Độ ẩm đất (Soil Moisture)││││
│  │ │ │ Ngưỡng tối ưu: 40-70%       ││││
│  │ │ │                              │││
│  │ │ │ 55.2 %          [Tối ưu]   ││││
│  │ │ └─────────────────────────────┘│││
│  │ │                                 │││
│  │ │ ┌─────────────────────────────┐│││
│  │ │ │ 🌡️ Nhiệt độ đất             ││││
│  │ │ │ Ngưỡng tối ưu: 15-30°C      │││
│  │ │ │                              │││
│  │ │ │ 23.5 °C         [Tối ưu]   ││││
│  │ │ └─────────────────────────────┘│││
│  │ │                                 │││
│  │ │ ┌─────────────────────────────┐│││
│  │ │ │ 🔬 Độ pH                    ││││
│  │ │ │ Ngưỡng tối ưu: 6.0-7.5      │││
│  │ │ │                              │││
│  │ │ │ 6.8             [Tối ưu]   ││││
│  │ │ └─────────────────────────────┘│││
│  │ │                                 │││
│  │ │ ┌─────────────────────────────┐│││
│  │ │ │ ⚡ Độ dẫn điện (EC)         ││││
│  │ │ │ Ngưỡng tối ưu: 1.0-3.0      │││
│  │ │ │                              │││
│  │ │ │ 2.1 mS/cm       [Tối ưu]   ││││
│  │ │ └─────────────────────────────┘│││
│  │ │   ... (N, P, K tương tự)       │││
│  │ └─────────────────────────────────┘││
│  │                                    ││
│  └────────────────────────────────────┘│
│                                          │
│           [Đóng]    [📊 Xem biểu đồ]   │
└─────────────────────────────────────────┘
```

---

## 📈 Chart Screen

```
┌─────────────────────────────────────────┐
│ ← Sensor Ruộng A              🔄        │
│   Node ID: 0xCC64                       │
├─────────────────────────────────────────┤
│  Chọn chỉ số:                           │
│  [Nhiệt độ] [Độ ẩm] [Pin] [RSSI]       │
│  [pH] [EC] [Nitơ(N)] [Phospho(P)] [K]  │
│                                          │
│  Khoảng thời gian:                      │
│  [1 giờ] [6 giờ] [24 giờ] [7 ngày]     │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │ Hiện tại  Trung bình  Thấp  Cao    ││
│  │  55.2%      58.1%     42.5%  72.3% ││
│  └─────────────────────────────────────┘│
│                                          │
│  ┌─────────────────────────────────────┐│
│  │ 75│                    📈           ││
│  │   │        ╱╲                       ││
│  │ 60│     ╱╲╱  ╲╱╲                    ││
│  │   │   ╱           ╲                 ││
│  │ 45│ ╱               ╲╲              ││
│  │   │                   ╲             ││
│  │ 30└──────────────────────────────   ││
│  │    0h   6h   12h  18h  24h         ││
│  │                                     ││
│  │         Độ ẩm đất (%)              ││
│  └─────────────────────────────────────┘│
│                                          │
└─────────────────────────────────────────┘
```

**Màu sắc biểu đồ:**
- Độ ẩm/Nhiệt độ: 🟢 Xanh lá / 🟠 Cam
- pH: 🟣 Tím
- EC: 🟠 Cam
- N: 🟢 Xanh lá
- P: 🔵 Xanh dương  
- K: 🟤 Nâu

---

## 🎨 Color Scheme Summary

### Trạng thái giá trị:
- **🔴 Critical (Đỏ #D32F2F):** Nguy hiểm, cần hành động ngay
- **🟠 Warning (Cam #F57C00):** Cảnh báo, cần chú ý
- **🟢 Optimal (Xanh lá #388E3C):** Tối ưu, lý tưởng
- **🔵 Good (Xanh dương #1976D2):** Tốt, chấp nhận được
- **⚪ Neutral (Xám #757575):** Không có dữ liệu

### Icons mapping:
- 💧 Water Drop → Độ ẩm đất
- 🌡️ Thermostat → Nhiệt độ đất
- 🔬 Science → pH
- ⚡ Electric Bolt → EC
- 🌿 Grass → Nitơ (N)
- 🌸 Spa → Phospho (P)
- 🌾 Eco → Kali (K)

---

## 📐 Layout Specifications

### Home Screen Cards (Compact):
- Card size: Full width, auto height
- Metric grid: 2 columns × 3 rows (+ 1 row for N/P/K)
- Padding: 10px
- Border radius: 12px
- Border width: 1.5px

### Detail Dialog (Full):
- Card size: Full width
- Each metric card: Full width × ~120px height
- Padding: 16px
- Border radius: 16px
- Border width: 2px
- Font sizes:
  - Value: 36px bold
  - Unit: 16px
  - Label: 15px
  - Status badge: 13px

### Chart:
- Metric chips: Auto width, 40px height
- Chart area: Full width × 60% viewport height
- Line width: 3px
- Point size: 6px
- Grid: Light grey (#E0E0E0)

---

**🎯 Design Goals Achieved:**
✅ Clean, modern interface
✅ Intuitive color coding
✅ High information density without clutter
✅ Responsive and mobile-friendly
✅ Accessibility (large fonts, clear icons)
