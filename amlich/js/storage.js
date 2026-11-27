/**
 * Secure Client-Side Storage with Web Crypto API
 * AES-GCM 256-bit with PBKDF2-HMAC-SHA256 (100,000 iterations)
 * ZERO encryption keys or passphrases ever sent to GitHub or stored in repo.
 */

// Helper: Uint8Array <-> Base64
function arrayBufferToBase64(buffer) {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return window.btoa(binary);
}

function base64ToArrayBuffer(base64) {
  const binaryString = window.atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Derive AES-GCM key from user passphrase using PBKDF2
 */
async function deriveKey(passphrase, saltBuffer) {
  const enc = new TextEncoder();
  const keyMaterial = await window.crypto.subtle.importKey(
    'raw',
    enc.encode(passphrase),
    { name: 'PBKDF2' },
    false,
    ['deriveKey']
  );

  return window.crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: saltBuffer,
      iterations: 100000,
      hash: 'SHA-256'
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

/**
 * Encrypt arbitrary JSON serializable data with passphrase
 * Returns standard encrypted envelope object
 */
export async function encryptPrivateData(data, passphrase) {
  if (!passphrase || passphrase.length < 6) {
    throw new Error('Mật khẩu mã hóa phải có ít nhất 6 ký tự.');
  }

  const salt = window.crypto.getRandomValues(new Uint8Array(16));
  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(passphrase, salt);

  const enc = new TextEncoder();
  const plaintextBuffer = enc.encode(JSON.stringify(data));

  const ciphertextBuffer = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: iv },
    key,
    plaintextBuffer
  );

  return {
    version: 1,
    encrypted: true,
    salt: arrayBufferToBase64(salt),
    iv: arrayBufferToBase64(iv),
    ciphertext: arrayBufferToBase64(ciphertextBuffer),
    updated_at: new Date().toISOString()
  };
}

/**
 * Decrypt standard envelope object with passphrase
 */
export async function decryptPrivateData(envelope, passphrase) {
  if (!envelope || !envelope.encrypted) {
    throw new Error('Dữ liệu không phải định dạng mã hóa hợp lệ.');
  }
  if (!passphrase) {
    throw new Error('Vui lòng nhập mật khẩu giải mã.');
  }

  const salt = base64ToArrayBuffer(envelope.salt);
  const iv = base64ToArrayBuffer(envelope.iv);
  const ciphertext = base64ToArrayBuffer(envelope.ciphertext);

  const key = await deriveKey(passphrase, salt);

  try {
    const decryptedBuffer = await window.crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: new Uint8Array(iv) },
      key,
      ciphertext
    );
    const dec = new TextDecoder();
    return JSON.parse(dec.decode(decryptedBuffer));
  } catch (err) {
    throw new Error('Mật khẩu giải mã không đúng hoặc dữ liệu bị hỏng.');
  }
}

/**
 * Local Storage Wrapper
 */
export const StorageManager = {
  get(key, defaultValue = null) {
    try {
      const item = localStorage.getItem(key);
      return item ? JSON.parse(item) : defaultValue;
    } catch {
      return defaultValue;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {
      console.error('Storage set failed', e);
    }
  },
  remove(key) {
    localStorage.removeItem(key);
  }
};
