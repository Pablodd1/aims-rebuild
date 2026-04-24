import { NextResponse } from 'next/server';

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8659726749:AAHt5annAdlRTkG_nLwfT8n5HNj5duPJA90';
const ADMIN_CHAT_ID = '7838956683';

async function sendTelegramMessage(chatId: string, text: string, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: chatId, text }),
      });
      if (res.ok) return true;
    } catch (err) {
      console.error(`Send attempt ${i + 1} failed:`, err);
      if (i < retries - 1) await new Promise(r => setTimeout(r, 1000 * (i + 1)));
    }
  }
  return false;
}

export async function POST(request: Request) {
  // Respond immediately to Telegram
  const response = NextResponse.json({ ok: true });

  try {
    const body = await request.json();

    if (!body.update_id) {
      return response;
    }

    const message = body.message;
    if (!message || !message.text) {
      return response;
    }

    const chatId = message.chat.id.toString();
    const text = message.text;
    const username = message.from?.username || message.from?.first_name || 'Unknown';

    // Fire-and-forget - respond to user immediately
    sendTelegramMessage(chatId, `📨 Received: "${text}"\n\nI'll process this shortly. Check https://aims-rebuild.vercel.app`);

    // Forward to admin if not from admin
    if (chatId !== ADMIN_CHAT_ID) {
      sendTelegramMessage(ADMIN_CHAT_ID, `📱 Message from ${username}:\n\n${text}`);
    }
  } catch (err) {
    console.error('Telegram webhook error:', err);
  }

  return response;
}

// Handle Telegram verification
export async function GET() {
  return NextResponse.json({ status: 'Telegram webhook active', bot: '@Hermescto2bot' });
}
