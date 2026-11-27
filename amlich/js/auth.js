/**
 * GitHub Authentication and Configuration Manager
 * Handles tokens strictly in-memory or sessionStorage.
 * Verifies repository read/write permissions.
 */

const SESSION_AUTH_KEY = 'amlich_gh_auth_session';
const CONFIG_KEY = 'amlich_gh_config';

export class AuthManager {
  constructor() {
    this.token = null;
    this.user = null;
    this.config = this.loadConfig();
    this.initFromSession();
  }

  loadConfig() {
    try {
      const saved = localStorage.getItem(CONFIG_KEY);
      if (saved) return JSON.parse(saved);
    } catch {}
    return {
      owner: 'vdt34',
      repo: 'vdt34.github.io',
      branch: 'main',
      basePath: 'amlich/'
    };
  }

  saveConfig(newConfig) {
    this.config = { ...this.config, ...newConfig };
    localStorage.setItem(CONFIG_KEY, JSON.stringify(this.config));
  }

  initFromSession() {
    try {
      const raw = sessionStorage.getItem(SESSION_AUTH_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        this.token = parsed.token;
        this.user = parsed.user;
      }
    } catch {}
  }

  isAuthenticated() {
    return Boolean(this.token);
  }

  getToken() {
    return this.token;
  }

  getUser() {
    return this.user;
  }

  async login(token, owner = null, repo = null, branch = null) {
    if (!token || token.trim().length === 0) {
      throw new Error('Vui lòng cung cấp GitHub Personal Access Token (Fine-grained hoặc Classic).');
    }

    const cleanToken = token.trim();
    if (cleanToken.startsWith('ghp_') === false && cleanToken.startsWith('github_pat_') === false) {
      console.warn('Token does not start with standard prefix (ghp_ or github_pat_). Proceeding anyway.');
    }

    if (owner) this.config.owner = owner.trim();
    if (repo) this.config.repo = repo.trim();
    if (branch) this.config.branch = branch.trim();
    this.saveConfig(this.config);

    // 1. Verify user profile
    const userResp = await fetch('https://api.github.com/user', {
      headers: {
        'Authorization': `Bearer ${cleanToken}`,
        'Accept': 'application/vnd.github.v3+json'
      }
    });

    if (!userResp.ok) {
      if (userResp.status === 401) {
        throw new Error('Token không hợp lệ hoặc đã hết hạn (401 Unauthorized).');
      }
      throw new Error(`Xác thực người dùng thất bại: HTTP ${userResp.status}`);
    }

    const userData = await userResp.json();

    // 2. Verify repository permissions
    const repoResp = await fetch(`https://api.github.com/repos/${this.config.owner}/${this.config.repo}`, {
      headers: {
        'Authorization': `Bearer ${cleanToken}`,
        'Accept': 'application/vnd.github.v3+json'
      }
    });

    if (!repoResp.ok) {
      if (repoResp.status === 404) {
        throw new Error(`Không tìm thấy repository '${this.config.owner}/${this.config.repo}'. Vui lòng kiểm tra lại quyền truy cập của Token.`);
      }
      throw new Error(`Không thể truy cập repository: HTTP ${repoResp.status}`);
    }

    const repoData = await repoResp.json();
    const canPush = repoData.permissions ? repoData.permissions.push : false;

    if (!canPush) {
      throw new Error(`Token không có quyền ghi (Push/Write) vào repository '${this.config.owner}/${this.config.repo}'. Vui lòng cấp quyền Contents: Read and Write.`);
    }

    this.token = cleanToken;
    this.user = {
      login: userData.login,
      avatar_url: userData.avatar_url,
      name: userData.name || userData.login,
      can_push: canPush
    };

    // Store only in sessionStorage so closing tab or browser wipes it
    sessionStorage.setItem(SESSION_AUTH_KEY, JSON.stringify({
      token: this.token,
      user: this.user
    }));

    return this.user;
  }

  logout() {
    this.token = null;
    this.user = null;
    sessionStorage.removeItem(SESSION_AUTH_KEY);
  }
}
