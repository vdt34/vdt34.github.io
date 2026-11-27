/**
 * Member Profile Drawer & Kinship Detail Controller
 */

export class MemberModalController {
  constructor(clanData, kinshipResolver, onSaveMember, onSetSelf) {
    this.clanData = clanData;
    this.kinship = kinshipResolver;
    this.onSave = onSaveMember;
    this.onSetSelf = onSetSelf;
    this.currentMember = null;
    this.selfId = null;

    this.drawerEl = document.getElementById('member-drawer');
    this.initEvents();
  }

  setSelf(selfId) {
    this.selfId = selfId;
    if (this.currentMember) {
      this.renderKinshipBox(this.currentMember);
    }
  }

  initEvents() {
    document.getElementById('btn-close-drawer')?.addEventListener('click', () => {
      this.close();
    });

    document.getElementById('btn-set-self')?.addEventListener('click', () => {
      if (!this.currentMember) return;
      this.selfId = this.currentMember.id;
      if (this.onSetSelf) this.onSetSelf(this.currentMember.id);
      this.renderKinshipBox(this.currentMember);
    });

    document.getElementById('btn-open-edit')?.addEventListener('click', () => {
      this.openEditModal(this.currentMember);
    });

    // Edit form save
    document.getElementById('member-edit-form')?.addEventListener('submit', (e) => {
      e.preventDefault();
      this.handleSave();
    });

    document.querySelectorAll('.btn-close-edit-modal').forEach(b => {
      b.addEventListener('click', () => {
        document.getElementById('member-edit-modal').style.display = 'none';
      });
    });
  }

  open(memberId) {
    const m = this.clanData.members.find(x => x.id === memberId);
    if (!m) return;
    this.currentMember = m;

    document.getElementById('drawer-name').textContent = m.name;
    document.getElementById('drawer-generation').textContent = `Đời thứ ${m.generation || 1}`;
    document.getElementById('drawer-title').textContent = m.title || (m.gender === 'male' ? 'Nam' : 'Nữ');
    document.getElementById('drawer-status').innerHTML = m.is_alive
      ? '<span class="status-badge alive">Còn sống</span>'
      : '<span class="status-badge deceased">🕯️ Đã quy tiên</span>';

    document.getElementById('drawer-years').textContent = `${m.birth_year || '?'}${m.death_year ? ' – ' + m.death_year : ''}`;

    // Death Anniversary
    const deathSection = document.getElementById('drawer-death-section');
    if (!m.is_alive && m.death) {
      deathSection.style.display = 'block';
      document.getElementById('drawer-lunar-death').textContent = `Ngày ${m.death.lunar_day} tháng ${m.death.lunar_month} Âm lịch`;
      document.getElementById('drawer-death-note').textContent = m.death.note || 'Không có ghi chú thêm.';
    } else {
      deathSection.style.display = 'none';
    }

    // Grave
    const graveSection = document.getElementById('drawer-grave-section');
    if (!m.is_alive && m.grave && m.grave.location) {
      graveSection.style.display = 'block';
      document.getElementById('drawer-grave-location').textContent = m.grave.location;
      document.getElementById('drawer-grave-desc').textContent = m.grave.description || '';
      const mapBtn = document.getElementById('btn-open-grave-maps');
      if (m.grave.lat && m.grave.lng) {
        mapBtn.style.display = 'inline-flex';
        mapBtn.href = `https://www.google.com/maps/search/?api=1&query=${m.grave.lat},${m.grave.lng}`;
      } else {
        mapBtn.style.display = 'none';
      }
    } else {
      graveSection.style.display = 'none';
    }

    // Biography
    document.getElementById('drawer-bio').textContent = m.bio || 'Chưa cập nhật tiểu sử chi tiết.';

    // Parents
    const father = this.clanData.members.find(x => x.id === m.father_id);
    const mother = this.clanData.members.find(x => x.id === m.mother_id);
    document.getElementById('drawer-parents').textContent = `${father ? father.name : '—'} / ${mother ? mother.name : '—'}`;

    // Spouses
    const spouseNames = (m.spouses || []).map(sid => {
      const sp = this.clanData.members.find(x => x.id === sid);
      return sp ? sp.name : sid;
    });
    document.getElementById('drawer-spouses').textContent = spouseNames.length > 0 ? spouseNames.join(', ') : 'Chưa có thông tin';

    // Children
    const childrenNames = (m.children || []).map(cid => {
      const ch = this.clanData.members.find(x => x.id === cid);
      return ch ? `${ch.name} (Đời ${ch.generation})` : cid;
    });
    document.getElementById('drawer-children').textContent = childrenNames.length > 0 ? childrenNames.join('; ') : 'Chưa có thông tin';

    this.renderKinshipBox(m);

    this.drawerEl.classList.add('open');
  }

  renderKinshipBox(targetMember) {
    const box = document.getElementById('drawer-kinship-box');
    if (!box) return;

    if (!this.selfId) {
      box.innerHTML = `
        <div style="font-size: 0.8125rem; color: var(--text-secondary);">
          Chưa chọn mốc "Tôi". Hãy bấm nút <strong>"Đặt làm 'Tôi'"</strong> ở trên để máy tính tự động tính danh xưng và vai vế xưng hô với toàn bộ họ hàng!
        </div>
      `;
      return;
    }

    const selfMember = this.clanData.members.find(x => x.id === this.selfId);
    const result = this.kinship.resolveRelationship(this.selfId, targetMember.id);

    box.innerHTML = `
      <div style="background: var(--bg-surface-hover); border-left: 4px solid var(--accent); padding: 0.75rem; border-radius: 6px;">
        <div style="font-size: 0.75rem; color: var(--text-muted); margin-bottom: 2px;">
          So sánh vai vế với: <strong>${selfMember?.name}</strong> (Tôi)
        </div>
        <div style="font-size: 1rem; font-weight: 700; color: var(--accent); margin-bottom: 4px;">
          ${result.relationship}
        </div>
        <div style="font-size: 0.8125rem; color: var(--text-primary); margin-bottom: 4px;">
          🗣️ Bạn gọi người đó là: <strong style="color: #b91c1c;">${result.callTarget}</strong>
        </div>
        <div style="font-size: 0.8125rem; color: var(--text-primary); margin-bottom: 4px;">
          👥 Người đó gọi bạn là: <strong>${result.callSource}</strong>
        </div>
        <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 4px;">
          💡 <em>${result.explanation}</em>
        </div>
      </div>
    `;
  }

  close() {
    this.drawerEl.classList.remove('open');
  }

  openEditModal(m) {
    if (!m) return;
    const modal = document.getElementById('member-edit-modal');
    document.getElementById('edit-member-id').value = m.id;
    document.getElementById('edit-member-name').value = m.name || '';
    document.getElementById('edit-member-gender').value = m.gender || 'male';
    document.getElementById('edit-member-generation').value = m.generation || 1;
    document.getElementById('edit-member-title').value = m.title || '';
    document.getElementById('edit-member-alive').checked = Boolean(m.is_alive);
    document.getElementById('edit-member-birth').value = m.birth_year || '';
    document.getElementById('edit-member-death-year').value = m.death_year || '';
    document.getElementById('edit-member-lunar-day').value = m.death?.lunar_day || '';
    document.getElementById('edit-member-lunar-month').value = m.death?.lunar_month || '';
    document.getElementById('edit-member-grave-location').value = m.grave?.location || '';
    document.getElementById('edit-member-bio').value = m.bio || '';

    modal.style.display = 'flex';
  }

  handleSave() {
    const id = document.getElementById('edit-member-id').value;
    const m = this.clanData.members.find(x => x.id === id);
    if (!m) return;

    m.name = document.getElementById('edit-member-name').value.trim();
    m.gender = document.getElementById('edit-member-gender').value;
    m.generation = parseInt(document.getElementById('edit-member-generation').value, 10);
    m.title = document.getElementById('edit-member-title').value.trim();
    m.is_alive = document.getElementById('edit-member-alive').checked;
    m.birth_year = parseInt(document.getElementById('edit-member-birth').value, 10) || null;
    m.death_year = parseInt(document.getElementById('edit-member-death-year').value, 10) || null;
    m.bio = document.getElementById('edit-member-bio').value.trim();

    const lDay = parseInt(document.getElementById('edit-member-lunar-day').value, 10);
    const lMonth = parseInt(document.getElementById('edit-member-lunar-month').value, 10);
    if (lDay && lMonth) {
      m.death = m.death || {};
      m.death.lunar_day = lDay;
      m.death.lunar_month = lMonth;
    }

    const gLoc = document.getElementById('edit-member-grave-location').value.trim();
    if (gLoc) {
      m.grave = m.grave || {};
      m.grave.location = gLoc;
    }

    document.getElementById('member-edit-modal').style.display = 'none';
    if (this.onSave) this.onSave(m);
    this.open(m.id);
  }
}
