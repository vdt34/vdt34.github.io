/**
 * Member Profile Drawer & Kinship Detail Controller
 * Handles viewing, adding (child, spouse, new member), editing, and deleting clan members.
 */

export class MemberModalController {
  constructor(clanData, kinshipResolver, onSaveMember, onSetSelf, onDeleteMember) {
    this.clanData = clanData;
    this.kinship = kinshipResolver;
    this.onSave = onSaveMember;
    this.onSetSelf = onSetSelf;
    this.onDelete = onDeleteMember;
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

    // Quick Add Child from Drawer
    document.getElementById('btn-drawer-add-child')?.addEventListener('click', () => {
      if (!this.currentMember) return;
      const isFather = this.currentMember.gender === 'male';
      const spouseId = (this.currentMember.spouses && this.currentMember.spouses.length > 0)
        ? this.currentMember.spouses[0]
        : null;
      this.openCreateModal({
        fatherId: isFather ? this.currentMember.id : spouseId,
        motherId: !isFather ? this.currentMember.id : spouseId,
        generation: (this.currentMember.generation || 1) + 1
      });
    });

    // Quick Add Spouse from Drawer
    document.getElementById('btn-drawer-add-spouse')?.addEventListener('click', () => {
      if (!this.currentMember) return;
      this.openCreateModal({
        spouseId: this.currentMember.id,
        gender: this.currentMember.gender === 'male' ? 'female' : 'male',
        generation: this.currentMember.generation || 1
      });
    });

    // Quick Add Spouse button from inside Edit Modal
    document.getElementById('btn-quick-add-spouse')?.addEventListener('click', () => {
      const curId = document.getElementById('edit-member-id')?.value;
      const curGender = document.getElementById('edit-member-gender')?.value || 'male';
      const curGen = parseInt(document.getElementById('edit-member-generation')?.value, 10) || 1;

      if (!curId) {
        alert('Vui lòng nhập họ tên và bấm "Lưu thành viên" trước, sau đó bấm thêm vợ/chồng cho thành viên này.');
        return;
      }

      const spouseGender = curGender === 'male' ? 'female' : 'male';
      this.openCreateModal({
        spouseId: curId,
        gender: spouseGender,
        generation: curGen
      });
    });

    // Gender change in modal updates spouse options
    document.getElementById('edit-member-gender')?.addEventListener('change', (e) => {
      const curId = document.getElementById('edit-member-id')?.value;
      const spouseSel = document.getElementById('edit-member-spouse');
      const curSpouse = spouseSel ? spouseSel.value : null;
      this.populateSpouseSelector(curId || null, curSpouse, e.target.value);
    });

    // Delete Member from Drawer
    document.getElementById('btn-drawer-delete')?.addEventListener('click', () => {
      if (!this.currentMember) return;
      if (confirm(`Bạn có chắc chắn muốn xóa thành viên "${this.currentMember.name}" khỏi gia phả?`)) {
        const idToDelete = this.currentMember.id;
        this.close();
        if (this.onDelete) this.onDelete(idToDelete);
      }
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

    const editModal = document.getElementById('member-edit-modal');
    editModal?.addEventListener('click', (e) => {
      if (e.target === editModal) {
        editModal.style.display = 'none';
      }
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
    const spouseList = (m.spouses || []).map(sid => {
      const sp = this.clanData.members.find(x => x.id === sid);
      return sp ? `<a href="#" class="drawer-spouse-link" data-id="${sp.id}" style="color: var(--gold); font-weight: 600; text-decoration: underline;">${sp.name}</a>` : sid;
    });

    const spouseContainer = document.getElementById('drawer-spouses');
    if (spouseContainer) {
      if (spouseList.length > 0) {
        spouseContainer.innerHTML = `${spouseList.join(', ')} <button type="button" class="btn btn-outline btn-sm btn-drawer-inline-spouse" style="padding: 1px 6px; font-size: 0.75rem; margin-left: 0.5rem; color: #ec4899; border-color: #fbcfe8;">💍 Thêm Vợ/Chồng</button>`;
      } else {
        spouseContainer.innerHTML = `<span style="color: var(--text-muted);">Chưa có thông tin</span> <button type="button" class="btn btn-outline btn-sm btn-drawer-inline-spouse" style="padding: 1px 6px; font-size: 0.75rem; margin-left: 0.5rem; color: #ec4899; border-color: #fbcfe8;">💍 Thêm Vợ/Chồng</button>`;
      }

      spouseContainer.querySelectorAll('.drawer-spouse-link').forEach(link => {
        link.addEventListener('click', (e) => {
          e.preventDefault();
          this.open(link.getAttribute('data-id'));
        });
      });

      spouseContainer.querySelectorAll('.btn-drawer-inline-spouse').forEach(btn => {
        btn.addEventListener('click', () => {
          this.openCreateModal({
            spouseId: m.id,
            gender: m.gender === 'male' ? 'female' : 'male',
            generation: m.generation || 1
          });
        });
      });
    }

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

  populateParentSelectors(fatherId = null, motherId = null) {
    const fatherSel = document.getElementById('edit-member-father');
    const motherSel = document.getElementById('edit-member-mother');
    if (!fatherSel || !motherSel) return;

    let fHtml = '<option value="">-- Không xác định cha --</option>';
    let mHtml = '<option value="">-- Không xác định mẹ --</option>';

    for (const m of this.clanData.members) {
      if (m.gender === 'male') {
        fHtml += `<option value="${m.id}" ${m.id === fatherId ? 'selected' : ''}>Đời ${m.generation}: ${m.name}</option>`;
      } else {
        mHtml += `<option value="${m.id}" ${m.id === motherId ? 'selected' : ''}>Đời ${m.generation}: ${m.name}</option>`;
      }
    }
    fatherSel.innerHTML = fHtml;
    motherSel.innerHTML = mHtml;
  }

  populateSpouseSelector(currentMemberId = null, selectedSpouseId = null, currentGender = 'male') {
    const spouseSel = document.getElementById('edit-member-spouse');
    const hintText = document.getElementById('spouse-hint-text');
    if (!spouseSel) return;

    let html = '<option value="">-- Chưa có phối ngẫu / Độc thân --</option>';

    // Filter members: exclude self
    const candidates = this.clanData.members.filter(m => m.id !== currentMemberId);

    // Prioritize opposite gender, then sort by generation
    candidates.sort((a, b) => {
      const aOpp = a.gender !== currentGender ? -1 : 1;
      const bOpp = b.gender !== currentGender ? -1 : 1;
      if (aOpp !== bOpp) return aOpp - bOpp;
      return (a.generation || 1) - (b.generation || 1);
    });

    for (const m of candidates) {
      const isSelected = m.id === selectedSpouseId;
      const genStr = m.generation ? `Đời ${m.generation}` : '';
      const genderStr = m.gender === 'male' ? 'Nam' : 'Nữ';
      const hasSpouse = m.spouses && m.spouses.length > 0;
      const spouseNote = hasSpouse && !isSelected ? ' (Đã kết hôn)' : '';
      html += `<option value="${m.id}" ${isSelected ? 'selected' : ''}>${genStr} • ${m.name} (${genderStr})${spouseNote}</option>`;
    }

    spouseSel.innerHTML = html;

    if (selectedSpouseId) {
      const sp = this.clanData.members.find(x => x.id === selectedSpouseId);
      if (hintText && sp) {
        hintText.textContent = `Đang kết nối phối ngẫu với: ${sp.name} (Đời ${sp.generation || 1})`;
      }
    } else if (hintText) {
      hintText.textContent = 'Chọn người phối ngẫu trong gia phả hoặc bấm "Thêm vợ/chồng mới".';
    }
  }

  openCreateModal(params = {}) {
    const modal = document.getElementById('member-edit-modal');
    const isSpouseCreation = Boolean(params.spouseId);
    const spouseTarget = isSpouseCreation ? this.clanData.members.find(x => x.id === params.spouseId) : null;

    if (isSpouseCreation && spouseTarget) {
      const roleName = params.gender === 'female' ? 'Vợ' : 'Chồng';
      document.getElementById('edit-modal-title').textContent = `💍 Thêm ${roleName} Cho: ${spouseTarget.name} (Đời ${spouseTarget.generation || 1})`;
    } else {
      document.getElementById('edit-modal-title').textContent = 'Thêm Thành Viên Mới';
    }

    document.getElementById('edit-member-id').value = ''; // empty means new member
    document.getElementById('edit-member-name').value = '';
    document.getElementById('edit-member-gender').value = params.gender || 'male';
    document.getElementById('edit-member-generation').value = params.generation || 1;
    document.getElementById('edit-member-title').value = '';
    document.getElementById('edit-member-alive').checked = true;
    document.getElementById('edit-member-birth').value = '';
    document.getElementById('edit-member-death-year').value = '';
    document.getElementById('edit-member-lunar-day').value = '';
    document.getElementById('edit-member-lunar-month').value = '';
    document.getElementById('edit-member-grave-location').value = '';
    document.getElementById('edit-member-bio').value = '';

    // Linked spouse for new creation
    this.pendingSpouseId = params.spouseId || null;

    this.populateParentSelectors(params.fatherId, params.motherId);
    this.populateSpouseSelector(null, params.spouseId || null, params.gender || 'male');

    modal.style.display = 'flex';
  }

  openEditModal(m) {
    if (!m) return;
    const modal = document.getElementById('member-edit-modal');
    document.getElementById('edit-modal-title').textContent = `Chỉnh Sửa Hồ Sơ: ${m.name}`;
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

    this.pendingSpouseId = null;
    const curSpouseId = (m.spouses && m.spouses.length > 0) ? m.spouses[0] : null;

    this.populateParentSelectors(m.father_id, m.mother_id);
    this.populateSpouseSelector(m.id, curSpouseId, m.gender || 'male');

    modal.style.display = 'flex';
  }

  handleSave() {
    const id = document.getElementById('edit-member-id').value;
    const name = document.getElementById('edit-member-name').value.trim();
    const gender = document.getElementById('edit-member-gender').value;
    const generation = parseInt(document.getElementById('edit-member-generation').value, 10) || 1;
    const title = document.getElementById('edit-member-title').value.trim();
    const is_alive = document.getElementById('edit-member-alive').checked;
    const birth_year = parseInt(document.getElementById('edit-member-birth').value, 10) || null;
    const death_year = parseInt(document.getElementById('edit-member-death-year').value, 10) || null;
    const bio = document.getElementById('edit-member-bio').value.trim();
    const father_id = document.getElementById('edit-member-father')?.value || null;
    const mother_id = document.getElementById('edit-member-mother')?.value || null;
    const spouse_id = document.getElementById('edit-member-spouse')?.value || this.pendingSpouseId || null;

    const lDay = parseInt(document.getElementById('edit-member-lunar-day').value, 10);
    const lMonth = parseInt(document.getElementById('edit-member-lunar-month').value, 10);
    let death = null;
    if (lDay && lMonth) {
      death = { lunar_day: lDay, lunar_month: lMonth, note: '' };
    }

    const gLoc = document.getElementById('edit-member-grave-location').value.trim();
    let grave = null;
    if (gLoc) {
      grave = { location: gLoc };
    }

    let memberObj;
    if (id) {
      // Update existing
      memberObj = this.clanData.members.find(x => x.id === id);
      if (!memberObj) return;
      memberObj.name = name;
      memberObj.gender = gender;
      memberObj.generation = generation;
      memberObj.title = title;
      memberObj.is_alive = is_alive;
      memberObj.birth_year = birth_year;
      memberObj.death_year = death_year;
      memberObj.bio = bio;
      memberObj.father_id = father_id;
      memberObj.mother_id = mother_id;
      if (death) memberObj.death = death;
      if (grave) memberObj.grave = grave;

      // Update spouse bi-directional relationship
      const oldSpouses = memberObj.spouses || [];
      const oldSpouseId = oldSpouses.length > 0 ? oldSpouses[0] : null;

      if (oldSpouseId && oldSpouseId !== spouse_id) {
        // Unlink old spouse
        memberObj.spouses = memberObj.spouses.filter(sid => sid !== oldSpouseId);
        const oldSpouse = this.clanData.members.find(x => x.id === oldSpouseId);
        if (oldSpouse && oldSpouse.spouses) {
          oldSpouse.spouses = oldSpouse.spouses.filter(sid => sid !== id);
        }
      }

      if (spouse_id) {
        memberObj.spouses = memberObj.spouses || [];
        if (!memberObj.spouses.includes(spouse_id)) {
          memberObj.spouses.push(spouse_id);
        }
        const newSpouse = this.clanData.members.find(x => x.id === spouse_id);
        if (newSpouse) {
          newSpouse.spouses = newSpouse.spouses || [];
          if (!newSpouse.spouses.includes(id)) {
            newSpouse.spouses.push(id);
          }
        }
      } else if (!spouse_id && oldSpouseId) {
        memberObj.spouses = [];
      }
    } else {
      // Create new
      const newId = `p${Date.now().toString().slice(-6)}`;
      memberObj = {
        id: newId,
        name,
        gender,
        generation,
        title,
        is_alive,
        birth_year,
        death_year,
        bio,
        father_id,
        mother_id,
        death,
        grave,
        spouses: spouse_id ? [spouse_id] : [],
        children: []
      };

      this.clanData.members.push(memberObj);

      // Link to spouse bi-directionally
      if (spouse_id) {
        const spouse = this.clanData.members.find(x => x.id === spouse_id);
        if (spouse) {
          spouse.spouses = spouse.spouses || [];
          if (!spouse.spouses.includes(newId)) {
            spouse.spouses.push(newId);
          }
        }
      }

      // Link to parent children list
      if (father_id) {
        const father = this.clanData.members.find(x => x.id === father_id);
        if (father) {
          father.children = father.children || [];
          if (!father.children.includes(newId)) father.children.push(newId);
        }
      }
      if (mother_id) {
        const mother = this.clanData.members.find(x => x.id === mother_id);
        if (mother) {
          mother.children = mother.children || [];
          if (!mother.children.includes(newId)) mother.children.push(newId);
        }
      }
    }

    document.getElementById('member-edit-modal').style.display = 'none';
    if (this.onSave) this.onSave(memberObj);
    this.open(memberObj.id);
  }
}
