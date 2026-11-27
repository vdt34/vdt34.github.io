/**
 * Book / Chronicle View (Phả Ký Dạng Sách Truyền Thống)
 * Groups clan lineage chronologically by generation, ready for reading or printing.
 */

export class BookViewRenderer {
  constructor(clanData, onSelectMember) {
    this.clanData = clanData;
    this.onSelect = onSelectMember;
  }

  render(container) {
    const { clan_info, members } = this.clanData;

    // Group by generation
    const byGen = new Map();
    for (const m of members) {
      const g = m.generation || 1;
      if (!byGen.has(g)) byGen.set(g, []);
      byGen.get(g).push(m);
    }

    const romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

    let html = `
      <div class="book-container">
        <!-- Title Page / Header -->
        <div class="book-header text-center">
          <h1 class="book-clan-title">${clan_info.name}</h1>
          <h3 class="book-clan-branch">${clan_info.branch || ''}</h3>
          <p class="book-clan-meta">
            <span>Nguyên quán: <strong>${clan_info.origin || ''}</strong></span> • 
            <span>Từ đường: <strong>${clan_info.hall || ''}</strong></span> • 
            <span>Thủy tổ: <strong>${clan_info.ancestor || ''}</strong></span>
          </p>
          <div class="book-divider">❖ ❖ ❖</div>
        </div>

        <div class="book-body">
    `;

    const sortedGens = Array.from(byGen.keys()).sort((a, b) => a - b);

    for (const gen of sortedGens) {
      const genRoman = romanNumerals[gen - 1] || gen;
      const genMembers = byGen.get(gen);

      html += `
        <section class="book-generation-section">
          <h2 class="generation-heading">ĐỜI THỨ ${genRoman}</h2>
          <div class="generation-members-list">
      `;

      for (const m of genMembers) {
        const isMale = m.gender === 'male';
        const isAlive = Boolean(m.is_alive);
        const spouseNames = (m.spouses || []).map(sid => {
          const sp = members.find(x => x.id === sid);
          return sp ? sp.name : sid;
        }).join(', ');

        const childrenNames = (m.children || []).map(cid => {
          const ch = members.find(x => x.id === cid);
          return ch ? ch.name : cid;
        }).join(', ');

        html += `
          <div class="book-member-card" data-id="${m.id}">
            <div class="book-member-header">
              <span class="book-member-name">${m.name}</span>
              <span class="book-member-title">(${m.title || (isMale ? 'Nam' : 'Nữ')})</span>
              ${!isAlive ? '<span class="tag-deceased">🕯️ Đã mất</span>' : '<span class="tag-alive">Còn sống</span>'}
            </div>

            <div class="book-member-details">
              <div><strong>Năm sinh/mất:</strong> ${m.birth_year || '?'}${m.death_year ? ' – ' + m.death_year : ''}</div>
              ${m.death?.lunar_day ? `<div><strong>Ngày Giỗ:</strong> Ngày ${m.death.lunar_day} tháng ${m.death.lunar_month} Âm lịch ${m.death.note ? '— ' + m.death.note : ''}</div>` : ''}
              ${spouseNames ? `<div><strong>Phối ngẫu (Vợ/Chồng):</strong> ${spouseNames}</div>` : ''}
              ${childrenNames ? `<div><strong>Hậu duệ (Con cái):</strong> ${childrenNames}</div>` : ''}
              ${m.grave?.location ? `<div><strong>Nơi an táng:</strong> ${m.grave.location}</div>` : ''}
              ${m.bio ? `<div class="book-member-bio"><strong>Tiểu sử:</strong> ${m.bio}</div>` : ''}
            </div>
          </div>
        `;
      }

      html += `
          </div>
        </section>
      `;
    }

    html += `
        </div>
      </div>
    `;

    container.innerHTML = html;

    // Attach click handlers
    container.querySelectorAll('.book-member-card').forEach(card => {
      card.addEventListener('click', () => {
        const id = card.getAttribute('data-id');
        if (this.onSelect) this.onSelect(id);
      });
    });
  }
}
