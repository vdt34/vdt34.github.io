/**
 * Vietnamese Kinship / Relationship Resolver (Máy tính xưng hô họ hàng)
 * Computes relationship distance and Vietnamese addressing terms between any two members.
 */

export class KinshipResolver {
  constructor(membersList) {
    this.membersMap = new Map();
    for (const m of membersList) {
      this.membersMap.set(m.id, m);
    }
  }

  getMember(id) {
    return this.membersMap.get(id);
  }

  /**
   * Find LCA (Lowest Common Ancestor) or shortest path between A and B
   */
  resolveRelationship(sourceId, targetId) {
    if (sourceId === targetId) {
      return {
        relationship: 'Bản thân (Chính bạn)',
        callTarget: 'Tôi',
        callSource: 'Tôi',
        generationDiff: 0,
        explanation: 'Bạn đã chọn chính mình.'
      };
    }

    const A = this.getMember(sourceId);
    const B = this.getMember(targetId);
    if (!A || !B) {
      return {
        relationship: 'Không tìm thấy dữ liệu',
        callTarget: 'Bạn',
        callSource: 'Tôi',
        explanation: 'Một trong hai thành viên không tồn tại trong hệ thống.'
      };
    }

    // 1. Check Spouse
    if (A.spouses && A.spouses.includes(B.id)) {
      const isHusband = B.gender === 'male';
      return {
        relationship: isHusband ? 'Chồng' : 'Vợ',
        callTarget: isHusband ? 'Chồng / Mình' : 'Vợ / Em',
        callSource: isHusband ? 'Vợ / Em' : 'Chồng / Anh',
        generationDiff: 0,
        explanation: `${B.name} là bạn đời của ${A.name}.`
      };
    }

    // 2. Direct Parent
    if (A.father_id === B.id || A.mother_id === B.id) {
      const isFather = B.gender === 'male';
      return {
        relationship: isFather ? 'Bố / Thân phụ' : 'Mẹ / Thân mẫu',
        callTarget: isFather ? 'Bố / Ba' : 'Mẹ / Mẹ',
        callSource: 'Con',
        generationDiff: -1,
        explanation: `${B.name} là cha/mẹ ruột của ${A.name}.`
      };
    }

    // 3. Direct Child
    if (B.father_id === A.id || B.mother_id === A.id) {
      const isSon = B.gender === 'male';
      return {
        relationship: isSon ? 'Con trai' : 'Con gái',
        callTarget: isSon ? 'Con trai' : 'Con gái',
        callSource: A.gender === 'male' ? 'Bố' : 'Mẹ',
        generationDiff: 1,
        explanation: `${B.name} là con ruột của ${A.name}.`
      };
    }

    // 4. Siblings (Cùng cha hoặc mẹ)
    const isSameFather = A.father_id && B.father_id && A.father_id === B.father_id;
    const isSameMother = A.mother_id && B.mother_id && A.mother_id === B.mother_id;
    if (isSameFather || isSameMother) {
      const isOlder = (B.birth_year || 0) < (A.birth_year || 0);
      if (isOlder) {
        return {
          relationship: B.gender === 'male' ? 'Anh ruột' : 'Chị ruột',
          callTarget: B.gender === 'male' ? 'Anh' : 'Chị',
          callSource: 'Em',
          generationDiff: 0,
          explanation: `${B.name} là anh/chị ruột của ${A.name} (sinh năm ${B.birth_year || '?'}).`
        };
      } else {
        return {
          relationship: B.gender === 'male' ? 'Em trai ruột' : 'Em gái ruột',
          callTarget: 'Em',
          callSource: A.gender === 'male' ? 'Anh' : 'Chị',
          generationDiff: 0,
          explanation: `${B.name} là em ruột của ${A.name} (sinh năm ${B.birth_year || '?'}).`
        };
      }
    }

    // 5. Grandparents (Ông / Bà nội - ngoại)
    const aFather = this.getMember(A.father_id);
    const aMother = this.getMember(A.mother_id);
    if ((aFather && (aFather.father_id === B.id || aFather.mother_id === B.id)) ||
        (aMother && (aMother.father_id === B.id || aMother.mother_id === B.id))) {
      const isMale = B.gender === 'male';
      const isNoi = aFather && (aFather.father_id === B.id || aFather.mother_id === B.id);
      const branchName = isNoi ? 'nội' : 'ngoại';
      return {
        relationship: isMale ? `Ông ${branchName}` : `Bà ${branchName}`,
        callTarget: isMale ? 'Ông' : 'Bà',
        callSource: 'Cháu',
        generationDiff: -2,
        explanation: `${B.name} là ông/bà ${branchName} của ${A.name}.`
      };
    }

    // 6. General Ancestors (Cụ / Kỵ)
    const genDiff = (B.generation || 0) - (A.generation || 0);

    if (genDiff <= -3) {
      const isMale = B.gender === 'male';
      return {
        relationship: isMale ? 'Cụ Tổ / Tiền bối' : 'Cụ Bà / Tiền bối',
        callTarget: isMale ? 'Cụ' : 'Cụ Bà',
        callSource: 'Chắt / Chút',
        generationDiff: genDiff,
        explanation: `${B.name} thuộc đời thứ ${B.generation}, bề trên của ${A.name} (đời thứ ${A.generation}).`
      };
    }

    // 7. Aunts / Uncles (Bác, Chú, Cô, Cậu, Dì cùng đời bố mẹ)
    if (genDiff === -1) {
      const isOlderThanParent = (B.birth_year || 0) < ((aFather?.birth_year || aMother?.birth_year) || 0);
      const isMale = B.gender === 'male';

      let rel = '';
      let callT = '';
      if (isMale) {
        if (isOlderThanParent) {
          rel = 'Bác họ (Anh của bố/mẹ)';
          callT = 'Bác';
        } else {
          rel = 'Chú / Cậu họ (Em trai của bố/mẹ)';
          callT = 'Chú';
        }
      } else {
        if (isOlderThanParent) {
          rel = 'Bác gái / Cô họ (Chị của bố/mẹ)';
          callT = 'Bác';
        } else {
          rel = 'Cô / Dì họ (Em gái của bố/mẹ)';
          callT = 'Cô';
        }
      }

      return {
        relationship: rel,
        callTarget: callT,
        callSource: 'Cháu',
        generationDiff: -1,
        explanation: `${B.name} cùng hàng với bố mẹ của ${A.name} trong gia tộc.`
      };
    }

    // 8. Same Generation Cousins (Anh/Chị/Em họ)
    if (genDiff === 0) {
      const isOlder = (B.birth_year || 0) < (A.birth_year || 0);
      const isMale = B.gender === 'male';
      return {
        relationship: isOlder ? (isMale ? 'Anh họ' : 'Chị họ') : (isMale ? 'Em trai họ' : 'Em gái họ'),
        callTarget: isOlder ? (isMale ? 'Anh' : 'Chị') : 'Em',
        callSource: isOlder ? 'Em' : (A.gender === 'male' ? 'Anh' : 'Chị'),
        generationDiff: 0,
        explanation: `${B.name} và ${A.name} cùng thuộc đời thứ ${A.generation} trong dòng họ.`
      };
    }

    // 9. Descendant Generation (Cháu họ / Chắt họ)
    if (genDiff === 1) {
      return {
        relationship: B.gender === 'male' ? 'Cháu trai trong họ' : 'Cháu gái trong họ',
        callTarget: 'Cháu',
        callSource: A.gender === 'male' ? 'Bác / Chú' : 'Bác / Cô',
        generationDiff: 1,
        explanation: `${B.name} thuộc thế hệ sau (đời ${B.generation}), gọi ${A.name} bằng Bác/Chú/Cô.`
      };
    }

    if (genDiff >= 2) {
      return {
        relationship: 'Chắt trong họ (Hậu duệ đời sau)',
        callTarget: 'Chắt / Con cháu',
        callSource: 'Cụ / Ông / Bà',
        generationDiff: genDiff,
        explanation: `${B.name} cách ${A.name} ${genDiff} đời.`
      };
    }

    return {
      relationship: 'Họ hàng cùng tộc',
      callTarget: 'Anh/Chị/Em/Cháu',
      callSource: 'Tôi',
      generationDiff: genDiff,
      explanation: `Hai người có quan hệ trong gia phả Họ Vũ.`
    };
  }

  /**
   * Check whether two people are blood relatives (share an ancestor or direct lineage).
   * In Vietnamese clan genealogy, blood relatives cannot be spouses.
   */
  isBloodRelative(id1, id2) {
    if (!id1 || !id2) return false;
    if (id1 === id2) return true;

    const getAncestors = (id) => {
      const ancestors = new Set();
      const queue = [id];
      while (queue.length > 0) {
        const curId = queue.shift();
        const cur = this.getMember(curId);
        if (!cur) continue;
        if (cur.father_id && !ancestors.has(cur.father_id)) {
          ancestors.add(cur.father_id);
          queue.push(cur.father_id);
        }
        if (cur.mother_id && !ancestors.has(cur.mother_id)) {
          ancestors.add(cur.mother_id);
          queue.push(cur.mother_id);
        }
      }
      return ancestors;
    };

    const anc1 = getAncestors(id1);
    const anc2 = getAncestors(id2);

    // Direct ancestor/descendant
    if (anc1.has(id2) || anc2.has(id1)) return true;

    // Shared common ancestor (brother/sister, cousin, clan bloodline)
    for (const a of anc1) {
      if (anc2.has(a)) return true;
    }

    return false;
  }
}
