/**
 * Cloudflare Worker thay thế máy chủ vov.truongblack.me (Hoàn toàn miễn phí, hỗ trợ dynamic query ?song=)
 * Triển khai: Đăng nhập dash.cloudflare.com -> Workers & Pages -> Create Worker -> Dán mã này và Deploy.
 */

const VOV_CHANNELS = [
  {
    channel: "VOV1",
    name: "VOV1 - Thời sự & Chính trị",
    description: "Kênh Thời sự, Chính trị, Tổng hợp - Đài Tiếng nói Việt Nam",
    audio_url: "https://str.vov.gov.vn/vovlive/vov1vov5Vietnamese.sdp_aac/playlist.m3u8"
  },
  {
    channel: "VOV2",
    name: "VOV2 - Văn hóa & Xã hội",
    description: "Kênh Văn hóa, Đời sống, Xã hội, Giáo dục, Dân tộc",
    audio_url: "https://str.vov.gov.vn/vovlive/vov2.sdp_aac/playlist.m3u8"
  },
  {
    channel: "VOV3",
    name: "VOV3 - Âm nhạc & Giải trí",
    description: "Kênh Âm nhạc và Thông tin giải trí thanh thiếu niên",
    audio_url: "https://str.vov.gov.vn/vovlive/vov3.sdp_aac/playlist.m3u8"
  },
  {
    channel: "VOV5",
    name: "VOV5 - Kênh Đối ngoại",
    description: "Kênh Phát thanh Đối ngoại - Phát sóng đa ngôn ngữ",
    audio_url: "https://str.vov.gov.vn/vovlive/vov5.sdp_aac/playlist.m3u8"
  },
  {
    channel: "VOV_GT_HN",
    name: "VOV Giao thông Hà Nội (FM 91 MHz)",
    description: "Kênh thông tin giao thông đô thị Hà Nội và các tỉnh phía Bắc",
    audio_url: "https://play.vovgiaothong.vn/live/gthn/playlist.m3u8"
  },
  {
    channel: "VOV_GT_HCM",
    name: "VOV Giao thông TP.HCM (FM 90 MHz)",
    description: "Kênh thông tin giao thông đô thị TP. Hồ Chí Minh và Nam Bộ",
    audio_url: "https://play.vovgiaothong.vn/live/gthcm/playlist.m3u8"
  },
  {
    channel: "VOV_MEKONG",
    name: "VOV Giao thông Mekong",
    description: "Kênh thông tin giao thông khu vực Đồng bằng sông Cửu Long",
    audio_url: "https://play.vovgiaothong.vn/live/mekong/playlist.m3u8"
  }
];

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const headers = {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers });
    }

    // 1. Endpoint /vov/list
    if (url.pathname === "/vov/list" || url.pathname === "/vov/list/") {
      return new Response(JSON.stringify({
        success: true,
        total: VOV_CHANNELS.length,
        radios: VOV_CHANNELS
      }, null, 2), { headers });
    }

    // 2. Endpoint /stream_pcm?song=...
    if (url.pathname === "/stream_pcm" || url.pathname === "/stream_pcm/") {
      const songParam = (url.searchParams.get("song") || "vov1").toLowerCase().trim();
      
      let matched = VOV_CHANNELS.find(c => 
        c.channel.toLowerCase() === songParam ||
        c.name.toLowerCase().includes(songParam) ||
        songParam.includes(c.channel.toLowerCase())
      );

      if (!matched) {
        matched = VOV_CHANNELS[0]; // Mặc định VOV1 nếu không khớp
      }

      return new Response(JSON.stringify({
        success: true,
        channel: matched.channel,
        name: matched.name,
        audio_url: matched.audio_url
      }, null, 2), { headers });
    }

    return new Response(JSON.stringify({
      error: "Not Found",
      available_endpoints: ["/vov/list", "/stream_pcm?song=VOV1"]
    }), { status: 404, headers });
  }
};
