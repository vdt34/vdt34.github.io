/**
 * Gravesite Locator & Mapping Module (Bản Đồ Mộ Phần Tổ Tiên)
 */

export class GraveMapRenderer {
  constructor(clanData, onSelectMember) {
    this.clanData = clanData;
    this.onSelect = onSelectMember;
  }

  render(container) {
    const graveMembers = this.clanData.members.filter(m => m.grave && m.grave.location);

    if (graveMembers.length === 0) {
      container.innerHTML = `
        <div style="padding: 3rem; text-align: center; color: var(--text-muted);">
          Chưa có dữ liệu vị trí mộ phần. Bạn có thể bấm vào từng cụ để cập nhật địa chỉ và tọa độ GPS.
        </div>
      `;
      return;
    }

    let cardsHtml = '';
    for (const m of graveMembers) {
      const g = m.grave;
      const hasCoords = g.lat && g.lng;
      const gmapsUrl = hasCoords ? `https://www.google.com/maps/search/?api=1&query=${g.lat},${g.lng}` : null;

      cardsHtml += `
        <div class="grave-card">
          <div class="grave-card-header">
            <div>
              <h3 class="grave-card-name">${m.name}</h3>
              <span class="grave-card-gen">Đời thứ ${m.generation || 1} • ${m.title || ''}</span>
            </div>
            ${hasCoords ? `<a href="${gmapsUrl}" target="_blank" rel="noopener noreferrer" class="btn btn-primary btn-sm btn-nav-map">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>
              Chỉ đường Google Maps
            </a>` : ''}
          </div>

          <div class="grave-card-body">
            <div class="grave-item">
              <span class="grave-icon">📍</span>
              <strong>Vị trí:</strong>
              <span>${g.location}</span>
            </div>
            ${g.name ? `<div class="grave-item"><span class="grave-icon">🏛️</span><strong>Khu lăng mộ:</strong><span>${g.name}</span></div>` : ''}
            ${g.description ? `<div class="grave-item"><span class="grave-icon">📝</span><strong>Chỉ dẫn:</strong><span>${g.description}</span></div>` : ''}
            ${hasCoords ? `<div class="grave-item coords-tag"><span class="grave-icon">🌐</span><strong>Tọa độ GPS:</strong><code>${g.lat.toFixed(6)}, ${g.lng.toFixed(6)}</code></div>` : ''}
          </div>

          <div class="grave-card-footer">
            <button type="button" class="btn btn-outline btn-sm btn-view-profile" data-id="${m.id}">
              Xem hồ sơ & ngày giỗ
            </button>
          </div>
        </div>
      `;
    }

    container.innerHTML = `
      <div class="graves-container">
        <div class="graves-header">
          <h2>Bản Đồ & Danh Sách Mộ Phần Tổ Tiên</h2>
          <p>Lưu trữ vị trí chính xác và tọa độ GPS các phần mộ gia tộc, giúp con cháu viếng thăm và tảo mộ thuận tiện.</p>
        </div>
        <div class="graves-grid">
          ${cardsHtml}
        </div>
      </div>
    `;

    container.querySelectorAll('.btn-view-profile').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        if (this.onSelect) this.onSelect(id);
      });
    });
  }
}
