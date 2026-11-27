/**
 * GitHub REST API Client
 * Manages repository files, SHA hashing, conflict detection, and rate limiting.
 */

// UTF-8 safe Base64 encoding/decoding
function utf8ToBase64(str) {
  return window.btoa(unescape(encodeURIComponent(str)));
}

function base64ToUtf8(str) {
  return decodeURIComponent(escape(window.atob(str)));
}

export class GitHubAPI {
  constructor(authManager) {
    this.auth = authManager;
    this.rateLimit = {
      remaining: null,
      limit: null,
      reset: null
    };
  }

  getHeaders() {
    const headers = {
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json'
    };
    if (this.auth.isAuthenticated()) {
      headers['Authorization'] = `Bearer ${this.auth.getToken()}`;
    }
    return headers;
  }

  updateRateLimit(headers) {
    const rem = headers.get('x-ratelimit-remaining');
    const lim = headers.get('x-ratelimit-limit');
    const reset = headers.get('x-ratelimit-reset');
    if (rem !== null) this.rateLimit.remaining = parseInt(rem, 10);
    if (lim !== null) this.rateLimit.limit = parseInt(lim, 10);
    if (reset !== null) this.rateLimit.reset = new Date(parseInt(reset, 10) * 1000);
  }

  /**
   * Fetch a file from the repository
   * Returns { content: string, sha: string }
   */
  async getFile(filePath) {
    const { owner, repo, branch } = this.auth.config;
    const url = `https://api.github.com/repos/${owner}/${repo}/contents/${filePath}?ref=${branch}`;

    const resp = await fetch(url, { headers: this.getHeaders() });
    this.updateRateLimit(resp.headers);

    if (resp.status === 404) {
      return null;
    }

    if (!resp.ok) {
      if (resp.status === 403 && this.rateLimit.remaining === 0) {
        throw new Error(`GitHub API Rate limit exceeded. Thử lại sau: ${this.rateLimit.reset?.toLocaleTimeString()}`);
      }
      throw new Error(`Lỗi tải file '${filePath}': HTTP ${resp.status}`);
    }

    const data = await resp.json();
    const cleanContent = data.content.replace(/\n/g, '');
    const decoded = base64ToUtf8(cleanContent);
    return {
      content: decoded,
      sha: data.sha
    };
  }

  /**
   * Save or update a file in the repository with SHA conflict prevention
   * Returns { sha: string, commit: string }
   */
  async saveFile(filePath, contentString, commitMessage, currentSha = null) {
    if (!this.auth.isAuthenticated()) {
      throw new Error('Yêu cầu kết nối GitHub với quyền ghi để lưu dữ liệu.');
    }

    const { owner, repo, branch } = this.auth.config;
    const url = `https://api.github.com/repos/${owner}/${repo}/contents/${filePath}`;

    const body = {
      message: commitMessage,
      content: utf8ToBase64(contentString),
      branch: branch
    };

    if (currentSha) {
      body.sha = currentSha;
    } else {
      // Check if file exists to fetch sha
      const existing = await this.getFile(filePath);
      if (existing) {
        body.sha = existing.sha;
      }
    }

    const resp = await fetch(url, {
      method: 'PUT',
      headers: this.getHeaders(),
      body: JSON.stringify(body)
    });

    this.updateRateLimit(resp.headers);

    if (resp.status === 409) {
      throw new Error(`Xung đột dữ liệu (Conflict 409): File '${filePath}' đã bị thay đổi bởi commit khác trên GitHub. Vui lòng tải lại trang và thử lại để tránh ghi đè mất dữ liệu.`);
    }

    if (!resp.ok) {
      const errData = await resp.json().catch(() => ({}));
      throw new Error(`Không thể lưu file '${filePath}': ${errData.message || resp.statusText} (HTTP ${resp.status})`);
    }

    const resData = await resp.json();
    return {
      sha: resData.content ? resData.content.sha : null,
      commit: resData.commit ? resData.commit.sha : null
    };
  }
}
