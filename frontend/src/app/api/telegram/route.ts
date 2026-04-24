import { NextResponse } from 'next/server';
import crypto from 'crypto';

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8659726749:AAHt5annAdlRTkG_nLwfT8n5HNj5duPJA90';
const ADMIN_CHAT_ID = '7838956683';

function verifyTelegram(data: Record<string, string>, hash: string): boolean {
  const secretKey = crypto.createHmac('sha256', BOT_TOKEN).digest('hex');
  const sortedKeys = Object.keys(data).sort();
  const params = sortedKeys
    .filter(key => key !== 'hash')
    .map(key => `${key}=${data[key]}`)
    .join('\n');
  const hmac = crypto.createHmac('sha256', secretKey).update(params).digest('hex');
  return hmac === hash;
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    
    // Handle Telegram webhook
    if (body.update_id) {
      const message = body.message;
      if (message && message.text) {
        const chatId = message.chat.id.toString();
        const text = message.text;
        
        // Echo back to user
        await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id: chatId,
            text: `Received: ${text}\n\nBot is configured! Go to https://aims-rebuild.vercel.app`
          })
        });
        
        // Forward to admin if from user
        if (chatId !== ADMIN_CHAT_ID) {
          await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              chat_id: ADMIN_CHAT_ID,
              text: `📱 Telegram message from ${message.from?.username || message.from?.first_name}:\n\n${text}`
            })
          });
        }
      }
      return NextResponse.json({ ok: true });
    }
    
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error('Webhook error:', err);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
