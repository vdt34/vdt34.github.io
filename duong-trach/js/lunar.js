/**
 * Vietnamese Lunar-Solar Calendar & Almanac (UTC+7, 1900–2100)
 * Based on Jean Meeus Astronomical Algorithms / Ho Ngoc Duc.
 */
(function (global) {
  'use strict';

  const PI = Math.PI;
  const TZ = 7.0;

  const CAN = ['Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý'];
  const CHI = ['Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tị', 'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi'];
  const WEEKDAYS_VI = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

  const TIET_KHI = [
    'Xuân Phân', 'Thanh Minh', 'Cốc Vũ', 'Lập Hạ', 'Tiểu Mãn', 'Mang Chủng',
    'Hạ Chí', 'Tiểu Thử', 'Đại Thử', 'Lập Thu', 'Xử Thử', 'Bạch Lộ',
    'Thu Phân', 'Hàn Lộ', 'Sương Giáng', 'Lập Đông', 'Tiểu Tuyết', 'Đại Tuyết',
    'Đông Chí', 'Tiểu Hàn', 'Đại Hàn', 'Lập Xuân', 'Vũ Thủy', 'Kinh Trập'
  ];

  const GIO_HOANG_DAO = {
    0: [0, 1, 3, 6, 8, 9], 6: [0, 1, 3, 6, 8, 9],
    1: [2, 3, 5, 8, 10, 11], 7: [2, 3, 5, 8, 10, 11],
    2: [0, 1, 4, 5, 7, 10], 8: [0, 1, 4, 5, 7, 10],
    3: [0, 2, 3, 6, 7, 9], 9: [0, 2, 3, 6, 7, 9],
    4: [2, 4, 5, 8, 9, 11], 10: [2, 4, 5, 8, 9, 11],
    5: [1, 4, 6, 7, 10, 11], 11: [1, 4, 6, 7, 10, 11],
  };

  const GIO_KHUNG = [
    '23–1h', '1–3h', '3–5h', '5–7h', '7–9h', '9–11h',
    '11–13h', '13–15h', '15–17h', '17–19h', '19–21h', '21–23h'
  ];

  const HOANG_DAO_STARS = [
    ['Thanh Long', true], ['Minh Đường', true], ['Thiên Hình', false], ['Chu Tước', false],
    ['Kim Quỹ', true], ['Bảo Quang', true], ['Bạch Hổ', false], ['Ngọc Đường', true],
    ['Thiên Lao', false], ['Nguyên Vũ', false], ['Tư Mệnh', true], ['Câu Trần', false],
  ];

  const THAP_NHI_TRUC = [
    ['Kiến',  'good',    'Tốt xuất hành, khai trương, động thổ, nhậm chức; kiêng an táng, đào giếng.'],
    ['Trừ',   'good',    'Tốt trừ tà, chữa bệnh, dọn dẹp, giải trừ, động thổ; kiêng cưới hỏi, xuất tiền lớn.'],
    ['Mãn',   'good',    'Tốt cúng tế, cưới hỏi, khai trương, nhập trạch, cầu tài; kiêng kiện tụng, nhậm chức.'],
    ['Bình',  'good',    'Tốt tu sửa, san nền, dựng cột, cưới hỏi, giao dịch; kiêng kiện tụng, đào mương.'],
    ['Định',  'good',    'Tốt cưới hỏi, ký kết, nhập học, động thổ, giao dịch; kiêng kiện tụng, xuất hành xa.'],
    ['Chấp',  'good',    'Tốt xây dựng, khởi công, cưới hỏi, ký hợp đồng; kiêng dời nhà, xuất kho, đi xa.'],
    ['Phá',   'bad',     'Xấu cho việc lớn (cưới hỏi, khai trương, nhập trạch); chỉ hợp phá dỡ nhà cũ, chữa bệnh.'],
    ['Nguy',  'bad',     'Bất lợi leo cao, đi sông nước, cưới hỏi, khởi công lớn; hợp cúng tế, an sàng.'],
    ['Thành', 'good',    'Đại cát: tốt khai trương, cưới hỏi, nhập trạch, xuất hành, ký kết; kiêng kiện tụng.'],
    ['Thu',   'neutral', 'Hợp thu hoạch, đòi nợ, cất giữ, nạp tài; kiêng khai trương, xuất hành, an táng.'],
    ['Khai',  'good',    'Đại cát: tốt khai trương, động thổ, cưới hỏi, xuất hành, nhậm chức; kiêng an táng.'],
    ['Bế',    'bad',     'Xấu cho khai trương, cưới hỏi, động thổ; chỉ hợp đắp đê, xây tường, lấp hố, an táng.'],
  ];

  const NHI_THAP_BAT_TU = [
    ['Giác',   'Giác Mộc Giao',     'Mộc',    true,  'Cát tú: tốt cưới hỏi, xây dựng, nhậm chức, xuất hành; kiêng an táng.'],
    ['Cang',   'Cang Kim Long',     'Kim',    false, 'Hung tú: kiêng cưới hỏi, động thổ, khởi công, xuất hành.'],
    ['Đê',     'Đê Thổ Lạc',        'Thổ',    false, 'Hung tú: kiêng khởi công, cưới hỏi, đi thuyền, nhập trạch.'],
    ['Phòng',  'Phòng Nhật Thố',    'Nhật',   true,  'Cát tú: tốt cưới hỏi, xây dựng, dời nhà, khai trương, nhậm chức.'],
    ['Tâm',    'Tâm Nguyệt Hồ',     'Nguyệt', false, 'Hung tú: kỵ tạo tác, cưới hỏi, tranh chấp, kiện tụng.'],
    ['Vĩ',     'Vĩ Hỏa Hổ',         'Hỏa',    true,  'Cát tú: tốt khởi công, cưới hỏi, trổ cửa, đào ao, thủy lợi.'],
    ['Cơ',     'Cơ Thủy Báo',       'Thủy',   true,  'Cát tú: tốt khởi công, tu tạo, khai trương, đào mương, thu tài.'],
    ['Đẩu',    'Đẩu Mộc Giải',      'Mộc',    true,  'Cát tú: tốt xây dựng, trổ cửa, cưới hỏi, tạo tác, cầu tài.'],
    ['Ngưu',   'Ngưu Kim Ngưu',     'Kim',    false, 'Hung tú: kiêng khởi công xây dựng, cưới hỏi; hợp đi thuyền.'],
    ['Nữ',     'Nữ Thổ Bức',        'Thổ',    false, 'Hung tú: kiêng khởi công, an táng, kiện tụng, tranh chấp.'],
    ['Hư',     'Hư Nhật Thử',       'Nhật',   false, 'Hung tú: kiêng khởi công xây dựng, cưới hỏi, khai trương.'],
    ['Nguy',   'Nguy Nguyệt Yến',   'Nguyệt', false, 'Hung tú: kiêng xây dựng, an táng, khởi tạo việc lớn.'],
    ['Thất',   'Thất Hỏa Trư',      'Hỏa',    true,  'Đại Cát tú: khởi công trăm việc đều tốt (xây nhà, cưới hỏi, an táng).'],
    ['Bích',   'Bích Thủy Du',      'Thủy',   true,  'Đại Cát tú: tốt xây cất, cưới hỏi, khai trương, an táng, xuất hành.'],
    ['Khuê',   'Khuê Mộc Lang',     'Mộc',    false, 'Hung tú: kiêng khai trương, xuất hành, cưới hỏi; hợp tu sửa nhỏ.'],
    ['Lâu',    'Lâu Kim Cẩu',       'Kim',    true,  'Cát tú: tốt khởi công, dựng cột, cưới hỏi, trổ cửa, lập vườn.'],
    ['Vị',     'Vị Thổ Trĩ',        'Thổ',    true,  'Cát tú: tốt xây cất, cưới hỏi, an táng, khai trương, công danh.'],
    ['Mão',    'Mão Nhật Kê',       'Nhật',   false, 'Hung tú: kiêng xây dựng, cưới hỏi, trổ cửa, khai trương.'],
    ['Tất',    'Tất Nguyệt Ô',      'Nguyệt', true,  'Đại Cát tú: tốt xây cất, cưới hỏi, an táng, khai trương, xuất hành.'],
    ['Chủy',   'Chủy Hỏa Hầu',      'Hỏa',    false, 'Hung tú: đại kỵ khởi công xây dựng, an táng, cưới hỏi.'],
    ['Sâm',    'Sâm Thủy Viên',     'Thủy',   true,  'Cát tú: tốt khởi công, xây dựng, trổ cửa, nhậm chức; kiêng cưới hỏi, an táng.'],
    ['Tỉnh',   'Tỉnh Mộc Hãn',      'Mộc',    true,  'Cát tú: tốt xây nhà, trổ cửa, đào giếng, thủy lợi, nhậm chức; kiêng an táng.'],
    ['Quỷ',    'Quỷ Kim Dương',     'Kim',    false, 'Hung tú: kỵ cưới hỏi, khởi công, xuất hành; chỉ hợp an táng.'],
    ['Liễu',   'Liễu Thổ Chương',   'Thổ',    false, 'Hung tú: kỵ xây dựng, cưới hỏi, an táng, khai trương.'],
    ['Tinh',   'Tinh Nhật Mã',      'Nhật',   false, 'Bình/Hung tú: hợp xây phòng, tu tạo nhỏ; kiêng cưới hỏi, an táng.'],
    ['Trương', 'Trương Nguyệt Lộc', 'Nguyệt', true,  'Đại Cát tú: tốt khởi công, cưới hỏi, khai trương, an táng, cầu tài.'],
    ['Dực',    'Dực Hỏa Xà',        'Hỏa',    false, 'Hung tú: kiêng cưới hỏi, an táng, khởi công xây dựng lớn.'],
    ['Chẩn',   'Chẩn Thủy Dẫn',     'Thủy',   true,  'Cát tú: tốt xây dựng, cưới hỏi, an táng, xuất hành, khai trương.'],
  ];

  const NAP_AM_30 = [
    'Hải Trung Kim (Vàng trong biển)', 'Lư Trung Hỏa (Lửa trong lò)',
    'Đại Lâm Mộc (Cây rừng lớn)', 'Lộ Bàng Thổ (Đất ven đường)',
    'Kiếm Phong Kim (Vàng mũi kiếm)', 'Sơn Đầu Hỏa (Lửa trên núi)',
    'Giản Hạ Thủy (Nước khe suối)', 'Thành Đầu Thổ (Đất đầu thành)',
    'Bạch Lạp Kim (Vàng chân đèn)', 'Dương Liễu Mộc (Gỗ cây dương)',
    'Tuyền Trung Thủy (Nước trong suối)', 'Ốc Thượng Thổ (Đất nóc nhà)',
    'Tích Lịch Hỏa (Lửa sấm sét)', 'Tùng Bách Mộc (Gỗ tùng bách)',
    'Trường Lưu Thủy (Nước chảy dài)', 'Sa Trung Kim (Vàng trong cát)',
    'Sơn Hạ Hỏa (Lửa chân núi)', 'Bình Địa Mộc (Cây đồng bằng)',
    'Bích Thượng Thổ (Đất tò vò)', 'Kim Bạch Kim (Vàng pha bạc)',
    'Phúc Đăng Hỏa (Lửa đèn to)', 'Thiên Hà Thủy (Nước trên trời)',
    'Đại Trạch Thổ (Đất nền nhà)', 'Thoa Xuyến Kim (Vàng trang sức)',
    'Tang Đố Mộc (Gỗ cây dâu)', 'Đại Khê Thủy (Nước khe lớn)',
    'Sa Trung Thổ (Đất pha cát)', 'Thiên Thượng Hỏa (Lửa trên trời)',
    'Thạch Lựu Mộc (Gỗ cây lựu đá)', 'Đại Hải Thủy (Nước biển lớn)',
  ];

  const HUONG_XUAT_HANH = [
    ['Đông Bắc', 'Đông Nam'], ['Tây Bắc', 'Đông Nam'],
    ['Tây Nam', 'Đông'], ['Chính Nam', 'Đông'],
    ['Đông Nam', 'Chính Bắc'], ['Đông Bắc', 'Chính Nam'],
    ['Tây Bắc', 'Tây Nam'], ['Tây Nam', 'Tây Nam'],
    ['Chính Nam', 'Chính Tây'], ['Đông Nam', 'Chính Tây'],
  ];

  function INT(d) { return Math.floor(d); }
  function mod(a, b) { return ((a % b) + b) % b; }

  function jdFromDate(dd, mm, yy) {
    const a = INT((14 - mm) / 12);
    const y = yy + 4800 - a;
    const m = mm + 12 * a - 3;
    let jd = dd + INT((153 * m + 2) / 5) + 365 * y + INT(y / 4) - INT(y / 100) + INT(y / 400) - 32045;
    if (jd < 2299161) {
      jd = dd + INT((153 * m + 2) / 5) + 365 * y + INT(y / 4) - 32083;
    }
    return jd;
  }

  function jdToDate(jd) {
    let a, b, c;
    if (jd > 2299160) {
      a = jd + 32044;
      b = INT((4 * a + 3) / 146097);
      c = a - INT((b * 146097) / 4);
    } else {
      b = 0;
      c = jd + 32082;
    }
    const d = INT((4 * c + 3) / 1461);
    const e = c - INT((1461 * d) / 4);
    const m = INT((5 * e + 2) / 153);
    const day = e - INT((153 * m + 2) / 5) + 1;
    const month = m + 3 - 12 * INT(m / 10);
    const year = b * 100 + d - 4800 + INT(m / 10);
    return [day, month, year];
  }

  function newMoon(k) {
    const T = k / 1236.85;
    const T2 = T * T, T3 = T2 * T;
    const dr = PI / 180.0;
    let Jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3;
    Jd1 += 0.00033 * Math.sin((166.56 + 132.87 * T - 0.009173 * T2) * dr);
    const M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3;
    const Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3;
    const F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3;
    let C1 = (0.1734 - 0.000393 * T) * Math.sin(M * dr) + 0.0021 * Math.sin(2 * dr * M);
    C1 = C1 - 0.4068 * Math.sin(Mpr * dr) + 0.0161 * Math.sin(dr * 2 * Mpr);
    C1 = C1 - 0.0004 * Math.sin(dr * 3 * Mpr);
    C1 = C1 + 0.0104 * Math.sin(dr * 2 * F) - 0.0051 * Math.sin(dr * (M + Mpr));
    C1 = C1 - 0.0074 * Math.sin(dr * (M - Mpr)) + 0.0004 * Math.sin(dr * (2 * F + M));
    C1 = C1 - 0.0004 * Math.sin(dr * (2 * F - M)) - 0.0006 * Math.sin(dr * (2 * F + Mpr));
    C1 = C1 + 0.0010 * Math.sin(dr * (2 * F - Mpr)) + 0.0005 * Math.sin(dr * (2 * Mpr + M));
    const deltat = T < -11
      ? 0.001 + 0.000839 * T + 0.0002261 * T2 - 0.00000845 * T3 - 0.000000081 * T * T3
      : -0.000278 + 0.000265 * T + 0.000262 * T2;
    return Jd1 + C1 - deltat;
  }

  function sunLongitude(jdn) {
    const T = (jdn - 2451545.0) / 36525.0;
    const T2 = T * T;
    const dr = PI / 180.0;
    const M = 357.52910 + 35999.05030 * T - 0.0001559 * T2 - 0.00000048 * T * T2;
    const L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2;
    let DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * Math.sin(dr * M);
    DL += (0.019993 - 0.000101 * T) * Math.sin(dr * 2 * M) + 0.000290 * Math.sin(dr * 3 * M);
    let L = (L0 + DL) * dr;
    L -= PI * 2 * Math.floor(L / (PI * 2));
    return L;
  }

  function getSunLongitude(dayNumber, tz = TZ) {
    return INT(sunLongitude(dayNumber - 0.5 - tz / 24.0) / PI * 6);
  }

  function getNewMoonDay(k, tz = TZ) {
    return INT(newMoon(k) + 0.5 + tz / 24.0);
  }

  function getLunarMonth11(yy, tz = TZ) {
    const off = jdFromDate(31, 12, yy) - 2415021;
    const k = INT(off / 29.530588853);
    let nm = getNewMoonDay(k, tz);
    if (getSunLongitude(nm, tz) >= 9) nm = getNewMoonDay(k - 1, tz);
    return nm;
  }

  function getLeapMonthOffset(a11, tz = TZ) {
    const k = INT((a11 - 2415021.076998695) / 29.530588853 + 0.5);
    let last = 0, i = 1;
    let arc = getSunLongitude(getNewMoonDay(k + i, tz), tz);
    do {
      last = arc;
      i++;
      arc = getSunLongitude(getNewMoonDay(k + i, tz), tz);
    } while (arc !== last && i < 14);
    return i - 1;
  }

  function solarToLunar(dd, mm, yy, tz = TZ) {
    const dayNumber = jdFromDate(dd, mm, yy);
    const k = INT((dayNumber - 2415021.076998695) / 29.530588853);
    let monthStart = getNewMoonDay(k + 1, tz);
    if (monthStart > dayNumber) monthStart = getNewMoonDay(k, tz);
    let a11 = getLunarMonth11(yy, tz);
    let b11 = a11;
    let lunarYear;
    if (a11 >= monthStart) {
      lunarYear = yy;
      a11 = getLunarMonth11(yy - 1, tz);
    } else {
      lunarYear = yy + 1;
      b11 = getLunarMonth11(yy + 1, tz);
    }
    const lunarDay = dayNumber - monthStart + 1;
    const diff = INT((monthStart - a11) / 29);
    let lunarLeap = 0;
    let lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      const leapMonthDiff = getLeapMonthOffset(a11, tz);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff === leapMonthDiff) lunarLeap = 1;
      }
    }
    if (lunarMonth > 12) lunarMonth -= 12;
    if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;
    return [lunarDay, lunarMonth, lunarYear, lunarLeap];
  }

  function lunarToSolar(lunarDay, lunarMonth, lunarYear, lunarLeap = 0, tz = TZ) {
    let a11, b11;
    if (lunarMonth < 11) {
      a11 = getLunarMonth11(lunarYear - 1, tz);
      b11 = getLunarMonth11(lunarYear, tz);
    } else {
      a11 = getLunarMonth11(lunarYear, tz);
      b11 = getLunarMonth11(lunarYear + 1, tz);
    }
    const k = INT(0.5 + (a11 - 2415021.076998695) / 29.530588853);
    let off = lunarMonth - 11;
    if (off < 0) off += 12;
    if (b11 - a11 > 365) {
      const leapOff = getLeapMonthOffset(a11, tz);
      let leapMonth = leapOff - 2;
      if (leapMonth < 0) leapMonth += 12;
      if (lunarLeap !== 0 && lunarMonth !== leapMonth) return null;
      if (lunarLeap !== 0 || off >= leapOff) off += 1;
    } else if (lunarLeap !== 0) {
      return null;
    }
    const monthStart = getNewMoonDay(k + off, tz);
    const nextMonthStart = getNewMoonDay(k + off + 1, tz);
    const mlen = nextMonthStart - monthStart;
    if (lunarDay < 1 || lunarDay > mlen) return null;
    return jdToDate(monthStart + lunarDay - 1);
  }

  function getLunarMonthLength(lunarMonth, lunarYear, lunarLeap = 0, tz = TZ) {
    let a11, b11;
    if (lunarMonth < 11) {
      a11 = getLunarMonth11(lunarYear - 1, tz);
      b11 = getLunarMonth11(lunarYear, tz);
    } else {
      a11 = getLunarMonth11(lunarYear, tz);
      b11 = getLunarMonth11(lunarYear + 1, tz);
    }
    const k = INT(0.5 + (a11 - 2415021.076998695) / 29.530588853);
    let off = lunarMonth - 11;
    if (off < 0) off += 12;
    if (b11 - a11 > 365) {
      const leapOff = getLeapMonthOffset(a11, tz);
      let leapMonth = leapOff - 2;
      if (leapMonth < 0) leapMonth += 12;
      if (lunarLeap !== 0 && lunarMonth !== leapMonth) return 0;
      if (lunarLeap !== 0 || off >= leapOff) off += 1;
    } else if (lunarLeap !== 0) {
      return 0;
    }
    return getNewMoonDay(k + off + 1, tz) - getNewMoonDay(k + off, tz);
  }

  function getYearLeapMonth(lunarYear, tz = TZ) {
    const checks = [
      [lunarYear - 1, 1, 10],
      [lunarYear, 11, 12],
    ];
    for (const [baseY, minM, maxM] of checks) {
      const a11 = getLunarMonth11(baseY, tz);
      const b11 = getLunarMonth11(baseY + 1, tz);
      if (b11 - a11 > 365) {
        const leapOff = getLeapMonthOffset(a11, tz);
        let lm = leapOff - 2;
        if (lm <= 0) lm += 12;
        if (lm >= minM && lm <= maxM) return lm;
      }
    }
    return null;
  }

  function getCanChiYear(ly) { return CAN[mod(ly + 6, 10)] + ' ' + CHI[mod(ly + 8, 12)]; }
  function getCanChiMonth(lm, ly) { return CAN[mod(ly * 12 + lm + 3, 10)] + ' ' + CHI[mod(lm + 1, 12)]; }
  function getCanChiDay(jd) { return CAN[mod(jd + 9, 10)] + ' ' + CHI[mod(jd + 1, 12)]; }

  function getTietKhi(jd, tz = TZ) {
    const lonDeg = mod(sunLongitude(jd - tz / 24.0) * 180.0 / PI, 360.0);
    return TIET_KHI[mod(INT(lonDeg / 15.0), 24)];
  }

  function getNgayHoangDao(lunarMonth, jd) {
    const chiDay = mod(jd + 1, 12);
    const startChi = mod(lunarMonth - 1, 6) * 2;
    const idx = mod(chiDay - startChi, 12);
    const [name, isHD] = HOANG_DAO_STARS[idx];
    return { name, isHD, label: `${name} ${isHD ? 'Hoàng Đạo' : 'Hắc Đạo'}` };
  }

  function getTruc(jd, tz = TZ) {
    const lonDeg = mod(sunLongitude(jd - tz / 24.0) * 180.0 / PI, 360.0);
    const tietMonthIdx = INT(mod(lonDeg - 315.0, 360.0) / 30.0);
    const chiMonthTiet = mod(tietMonthIdx + 2, 12);
    const chiDay = mod(jd + 1, 12);
    const [name, rate, desc] = THAP_NHI_TRUC[mod(chiDay - chiMonthTiet, 12)];
    return { name, rate, desc };
  }

  function getNhiThapBatTu(jd) {
    const [shortName, fullName, hanh, good, desc] = NHI_THAP_BAT_TU[mod(jd + 11, 28)];
    return { shortName, fullName, hanh, good, desc };
  }

  function getNapAm(jd) {
    return NAP_AM_30[INT(mod(jd + 49, 60) / 2)];
  }

  function getXungKhac(jd) {
    const canD = mod(jd + 9, 10), chiD = mod(jd + 1, 12);
    const xungChi = mod(chiD + 6, 12);
    return `${CAN[mod(canD + 4, 10)]} ${CHI[xungChi]}, ${CAN[mod(canD + 6, 10)]} ${CHI[xungChi]} (xung tuổi ${CHI[xungChi]})`;
  }

  function getGioHoangDao(jd) {
    const chiD = mod(jd + 1, 12);
    return GIO_HOANG_DAO[chiD].map(g => `${CHI[g]} (${GIO_KHUNG[g]})`);
  }

  function getDayInfo(dd, mm, yy, tz = TZ) {
    const jd = jdFromDate(dd, mm, yy);
    const [ld, lm, ly, ll] = solarToLunar(dd, mm, yy, tz);
    const mlen = getLunarMonthLength(lm, ly, ll, tz);
    const hd = getNgayHoangDao(lm, jd);
    const truc = getTruc(jd, tz);
    const sao = getNhiThapBatTu(jd);
    const [hyThan, taiThan] = HUONG_XUAT_HANH[mod(jd + 9, 10)];
    return {
      jd,
      solar: [dd, mm, yy],
      weekday: WEEKDAYS_VI[mod(jd, 7)],
      lunar: [ld, lm, ly, ll],
      lunarMonthLen: mlen,
      canchiDay: getCanChiDay(jd),
      canchiMonth: getCanChiMonth(lm, ly),
      canchiYear: getCanChiYear(ly),
      tietKhi: getTietKhi(jd, tz),
      napAm: getNapAm(jd),
      hd,
      truc,
      sao,
      xungKhac: getXungKhac(jd),
      hyThan,
      taiThan,
      gioHoangDao: getGioHoangDao(jd),
    };
  }

  global.LunarVN = {
    jdFromDate, jdToDate, solarToLunar, lunarToSolar,
    getLunarMonthLength, getYearLeapMonth, getNgayHoangDao, getDayInfo,
  };
})(typeof window !== 'undefined' ? window : globalThis);
