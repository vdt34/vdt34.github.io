/**
 * Can Chi & Solar Terms (Tiết Khí) Module for Vietnam Lunar Calendar
 */

import { jdFromDate, getSunLongitude } from './vietnam-lunar.js';

export const CAN = ['Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý'];
export const CHI = ['Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi'];
export const ANIMALS = ['Chuột', 'Trâu', 'Hổ', 'Mèo', 'Rồng', 'Rắn', 'Ngựa', 'Dê', 'Khỉ', 'Gà', 'Chó', 'Lợn'];

export const SOLAR_TERMS = [
  'Xuân phân', 'Thanh minh', 'Cốc vũ', 'Lập hạ', 'Tiểu mãn', 'Mang chủng',
  'Hạ chí', 'Tiểu thử', 'Đại thử', 'Lập thu', 'Xử thử', 'Bạch lộ',
  'Thu phân', 'Hàn lộ', 'Sương giáng', 'Lập đông', 'Tiểu tuyết', 'Đại tuyết',
  'Đông chí', 'Tiểu hàn', 'Đại hàn', 'Lập xuân', 'Vũ thủy', 'Kinh trập'
];

/**
 * Get Can Chi for Year
 */
export function getYearCanChi(lunarYear) {
  let canIdx = (lunarYear + 6) % 10;
  let chiIdx = (lunarYear + 8) % 12;
  return {
    can: CAN[canIdx],
    chi: CHI[chiIdx],
    animal: ANIMALS[chiIdx],
    name: `${CAN[canIdx]} ${CHI[chiIdx]}`
  };
}

/**
 * Get Can Chi for Month
 */
export function getMonthCanChi(lunarMonth, lunarYear) {
  let yearCanIdx = (lunarYear + 6) % 10;
  // Khẩu quyết: Giáp Kỷ Bính tác sơ, Ất Canh Mậu vi đầu, Bính Tân Canh hướng thượng...
  let firstMonthCan = (yearCanIdx % 5 * 2 + 2) % 10;
  let canIdx = (firstMonthCan + lunarMonth - 1) % 10;
  // Tháng 1 âm là Dần (index 2)
  let chiIdx = (lunarMonth + 1) % 12;
  return {
    can: CAN[canIdx],
    chi: CHI[chiIdx],
    name: `${CAN[canIdx]} ${CHI[chiIdx]}`
  };
}

/**
 * Get Can Chi for Day
 */
export function getDayCanChi(dd, mm, yy) {
  let jd = jdFromDate(dd, mm, yy);
  let canIdx = (jd + 9) % 10;
  let chiIdx = (jd + 1) % 12;
  return {
    can: CAN[canIdx],
    chi: CHI[chiIdx],
    animal: ANIMALS[chiIdx],
    name: `${CAN[canIdx]} ${CHI[chiIdx]}`
  };
}

/**
 * Get Solar Term (Tiết Khí) index for day
 */
export function getSolarTerm(dd, mm, yy) {
  let jd = jdFromDate(dd, mm, yy);
  let termIdx = getSunLongitude(jd);
  // getSunLongitude gives index 0..11 for major terms, 
  // Map to 24 solar terms or return 12 principal terms
  return SOLAR_TERMS[termIdx * 2] || '';
}

/**
 * Check if day is Mùng 1 or Ngày Rằm
 */
export function isSpecialLunarDay(lunarDay) {
  if (lunarDay === 1) return { type: 'mung1', label: 'Mùng 1' };
  if (lunarDay === 15) return { type: 'ram', label: 'Ngày Rằm' };
  return null;
}
