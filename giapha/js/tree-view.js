/**
 * Interactive SVG Family Tree Visualizer
 * Hierarchical tree with zoom/pan, generation bands, spouse links, and card interactions.
 */

export class TreeVisualizer {
  constructor(containerId, onSelectMember, onSetSelf) {
    this.container = document.getElementById(containerId);
    this.onSelect = onSelectMember;
    this.onSetSelf = onSetSelf;
    this.members = [];
    this.selfId = null;

    // Viewport transform
    this.scale = 1.0;
    this.translateX = 60;
    this.translateY = 40;
    this.isDragging = false;
    this.startX = 0;
    this.startY = 0;

    this.initEvents();
  }

  setData(membersList, selfId = null) {
    this.members = membersList;
    this.selfId = selfId;
    this.render();
  }

  setSelf(id) {
    this.selfId = id;
    this.render();
  }

  initEvents() {
    this.container.addEventListener('mousedown', (e) => {
      if (e.target.closest('.tree-node')) return;
      this.isDragging = true;
      this.startX = e.clientX - this.translateX;
      this.startY = e.clientY - this.translateY;
    });

    window.addEventListener('mousemove', (e) => {
      if (!this.isDragging) return;
      this.translateX = e.clientX - this.startX;
      this.translateY = e.clientY - this.startY;
      this.applyTransform();
    });

    window.addEventListener('mouseup', () => {
      this.isDragging = false;
    });

    // Touch support for mobile
    let initialTouchDist = 0;
    this.container.addEventListener('touchstart', (e) => {
      if (e.touches.length === 1 && !e.target.closest('.tree-node')) {
        this.isDragging = true;
        this.startX = e.touches[0].clientX - this.translateX;
        this.startY = e.touches[0].clientY - this.translateY;
      } else if (e.touches.length === 2) {
        initialTouchDist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
      }
    });

    this.container.addEventListener('touchmove', (e) => {
      if (e.touches.length === 1 && this.isDragging) {
        this.translateX = e.touches[0].clientX - this.startX;
        this.translateY = e.touches[0].clientY - this.startY;
        this.applyTransform();
      } else if (e.touches.length === 2) {
        const dist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        const factor = dist / initialTouchDist;
        this.scale = Math.max(0.4, Math.min(2.5, this.scale * factor));
        initialTouchDist = dist;
        this.applyTransform();
      }
    });

    this.container.addEventListener('touchend', () => {
      this.isDragging = false;
    });

    // Wheel zoom
    this.container.addEventListener('wheel', (e) => {
      e.preventDefault();
      const zoomFactor = e.deltaY < 0 ? 1.1 : 0.9;
      this.zoom(zoomFactor, e.clientX, e.clientY);
    }, { passive: false });
  }

  zoom(factor, clientX = null, clientY = null) {
    const newScale = Math.max(0.4, Math.min(2.5, this.scale * factor));
    if (clientX !== null && clientY !== null) {
      const rect = this.container.getBoundingClientRect();
      const x = clientX - rect.left;
      const y = clientY - rect.top;
      this.translateX = x - (x - this.translateX) * (newScale / this.scale);
      this.translateY = y - (y - this.translateY) * (newScale / this.scale);
    }
    this.scale = newScale;
    this.applyTransform();
  }

  resetZoom() {
    this.scale = 1.0;
    this.translateX = 60;
    this.translateY = 40;
    this.applyTransform();
  }

  applyTransform() {
    const g = this.container.querySelector('.tree-viewport');
    if (g) {
      g.setAttribute('transform', `translate(${this.translateX}, ${this.translateY}) scale(${this.scale})`);
    }
  }

  /**
   * Layout calculation: Group by generation, arrange pairs and children
   */
  calculateLayout() {
    const cardWidth = 190;
    const cardHeight = 96;
    const gapX = 35;
    const gapY = 160;

    // Group by generation
    const byGen = new Map();
    for (const m of this.members) {
      const g = m.generation || 1;
      if (!byGen.has(g)) byGen.set(g, []);
      byGen.get(g).push(m);
    }

    const positions = new Map();
    const sortedGens = Array.from(byGen.keys()).sort((a, b) => a - b);

    // Coordinate mapping
    sortedGens.forEach((gen, gIdx) => {
      const list = byGen.get(gen);
      const y = gIdx * (cardHeight + gapY);

      // Order so that spouses stay close together and children under parents
      let currentX = 0;
      for (const m of list) {
        if (positions.has(m.id)) continue;
        positions.set(m.id, { x: currentX, y, width: cardWidth, height: cardHeight, member: m });
        currentX += cardWidth + gapX;

        // Place spouse next to member if spouse is in same generation
        if (m.spouses && m.spouses.length > 0) {
          for (const spId of m.spouses) {
            const sp = this.members.find(x => x.id === spId);
            if (sp && !positions.has(sp.id)) {
              positions.set(sp.id, { x: currentX, y, width: cardWidth, height: cardHeight, member: sp });
              currentX += cardWidth + gapX;
            }
          }
        }
      }
    });

    return positions;
  }

  render() {
    const positions = this.calculateLayout();
    if (!positions || positions.size === 0) {
      this.container.innerHTML = '<div style="padding: 2rem; text-align: center; color: var(--text-muted);">Chưa có dữ liệu gia phả.</div>';
      return;
    }

    let maxW = 2000;
    let maxH = 1500;
    positions.forEach(p => {
      if (p.x + p.width + 200 > maxW) maxW = p.x + p.width + 200;
      if (p.y + p.height + 200 > maxH) maxH = p.y + p.height + 200;
    });

    // Generate connectors (SVG Paths)
    let linksSvg = '';
    const memberMap = new Map(this.members.map(m => [m.id, m]));

    // 1. Parent to Child connectors
    positions.forEach((pos, id) => {
      const m = pos.member;
      if (m.father_id && positions.has(m.father_id)) {
        const fatherPos = positions.get(m.father_id);
        const motherPos = m.mother_id && positions.has(m.mother_id) ? positions.get(m.mother_id) : null;

        // Start link between father and mother if both exist
        let startX = fatherPos.x + fatherPos.width / 2;
        let startY = fatherPos.y + fatherPos.height;
        if (motherPos) {
          startX = (fatherPos.x + motherPos.x + motherPos.width) / 2;
        }

        const endX = pos.x + pos.width / 2;
        const endY = pos.y;
        const midY = (startY + endY) / 2;

        linksSvg += `
          <path d="M ${startX} ${startY} C ${startX} ${midY}, ${endX} ${midY}, ${endX} ${endY}"
                fill="none" stroke="var(--border-color)" stroke-width="2" opacity="0.85" />
        `;
      }
    });

    // 2. Spouse connectors (heart ring symbol)
    positions.forEach((pos, id) => {
      const m = pos.member;
      if (m.spouses) {
        for (const spId of m.spouses) {
          if (spId > m.id && positions.has(spId)) {
            const spPos = positions.get(spId);
            const x1 = Math.min(pos.x + pos.width, spPos.x + spPos.width);
            const x2 = Math.max(pos.x, spPos.x);
            const midY = pos.y + pos.height / 2;
            linksSvg += `
              <line x1="${pos.x + pos.width}" y1="${midY}" x2="${spPos.x}" y2="${midY}"
                    stroke="#ec4899" stroke-width="2" stroke-dasharray="4" opacity="0.75" />
            `;
          }
        }
      }
    });

    // Generate Node Cards
    let nodesSvg = '';
    positions.forEach((pos, id) => {
      const m = pos.member;
      const isMale = m.gender === 'male';
      const isAlive = Boolean(m.is_alive);
      const isSelf = this.selfId === m.id;

      const borderColor = isSelf ? '#eab308' : (isMale ? '#3b82f6' : '#ec4899');
      const avatarBg = isMale ? '#dbeafe' : '#fce7f3';
      const avatarColor = isMale ? '#1d4ed8' : '#be185d';
      const statusIcon = isAlive ? '' : '🕯️';
      const statusClass = isAlive ? 'alive' : 'deceased';

      nodesSvg += `
        <g class="tree-node ${statusClass} ${isSelf ? 'is-self' : ''}" data-id="${m.id}" transform="translate(${pos.x}, ${pos.y})" style="cursor: pointer;">
          <!-- Card Background -->
          <rect width="${pos.width}" height="${pos.height}" rx="10" ry="10"
                fill="var(--bg-surface)" stroke="${borderColor}" stroke-width="${isSelf ? '3' : '1.5'}"
                filter="drop-shadow(0 2px 4px rgba(0,0,0,0.06))" />

          <!-- Generation & Status Pill -->
          <rect x="8" y="8" width="52" height="18" rx="4" fill="${isMale ? '#eff6ff' : '#fdf2f8'}" />
          <text x="34" y="21" font-size="10" font-weight="600" fill="${avatarColor}" text-anchor="middle">Đời ${m.generation || 1}</text>

          ${statusIcon ? `<text x="${pos.width - 24}" y="22" font-size="13">${statusIcon}</text>` : ''}
          ${isSelf ? `<text x="${pos.width - 20}" y="22" font-size="11" font-weight="bold" fill="#eab308">★ Tôi</text>` : ''}

          <!-- Name -->
          <text x="14" y="47" font-size="13" font-weight="700" fill="var(--text-primary)" class="node-name">
            ${m.name}
          </text>

          <!-- Title / Role -->
          <text x="14" y="63" font-size="11" font-weight="500" fill="var(--text-secondary)">
            ${m.title || (isMale ? 'Nam' : 'Nữ')}
          </text>

          <!-- Years -->
          <text x="14" y="80" font-size="10.5" fill="var(--text-muted)">
            ${m.birth_year || '?'}${m.death_year ? ' – ' + m.death_year : (isAlive ? ' (Còn sống)' : '')}
          </text>
        </g>
      `;
    });

    this.container.innerHTML = `
      <svg class="tree-svg" width="100%" height="100%" viewBox="0 0 ${maxW} ${maxH}">
        <g class="tree-viewport" transform="translate(${this.translateX}, ${this.translateY}) scale(${this.scale})">
          <g class="tree-links">${linksSvg}</g>
          <g class="tree-nodes">${nodesSvg}</g>
        </g>
      </svg>
    `;

    // Attach click handlers to nodes
    this.container.querySelectorAll('.tree-node').forEach(node => {
      node.addEventListener('click', (e) => {
        const id = node.getAttribute('data-id');
        if (this.onSelect) this.onSelect(id);
      });
    });
  }
}
