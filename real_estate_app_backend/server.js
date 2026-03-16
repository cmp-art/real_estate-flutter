// backend/server.js
// SELCOM-ONLY BACKEND

const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// ── Supabase admin client (for updating subscriptions after payment) ──────────
// Requires SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY in .env
const { createClient } = require('@supabase/supabase-js');
const supabaseAdmin = (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY)
  ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  : null;

/**
 * Activate or update a user subscription in Supabase after successful payment.
 * orderMetadata is whatever was passed as `metadata` in the initialize call.
 */
async function activateSubscription(orderId, orderMetadata) {
  if (!supabaseAdmin) {
    console.warn('⚠️  Supabase not configured — subscription NOT updated in DB');
    return;
  }
  try {
    const userId = orderMetadata?.user_id;
    const tierName = orderMetadata?.tier ?? 'pro';
    if (!userId) { console.warn('⚠️  No user_id in metadata — cannot activate subscription'); return; }

    // Get the tier ID
    const { data: tier, error: tierErr } = await supabaseAdmin
      .from('subscription_tiers')
      .select('id')
      .eq('name', tierName)
      .single();
    if (tierErr || !tier) { console.error('❌ Tier not found:', tierName); return; }

    const expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + 1); // 1 month from now

    // Upsert subscription
    const { error } = await supabaseAdmin
      .from('user_subscriptions')
      .upsert({
        user_id:    userId,
        tier_id:    tier.id,
        status:     'active',
        started_at: new Date().toISOString(),
        expires_at: expiresAt.toISOString(),
        auto_renew: false,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' });

    if (error) { console.error('❌ Failed to activate subscription:', error); return; }

    // Log payment record
    await supabaseAdmin.from('payment_records').upsert({
      order_id:   orderId,
      user_id:    userId,
      tier:       tierName,
      status:     'completed',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'order_id' }).catch(() => {}); // non-fatal

    console.log(`✅ Subscription activated: user=${userId}, tier=${tierName}`);
  } catch (err) {
    console.error('❌ activateSubscription error:', err.message);
  }
}

// ========================================
// SELCOM PAYMENT GATEWAY
// ========================================

/**
 * Generate Selcom HMAC signature
 */
function generateSelcomSignature(orderId, amount, timestamp) {
  const data = `${orderId}${amount}${timestamp}`;
  return crypto
    .createHmac('sha256', process.env.SELCOM_API_SECRET)
    .update(data)
    .digest('hex');
}

/**
 * Initialize Selcom payment
 * POST /selcom/initialize
 */
app.post('/selcom/initialize', async (req, res) => {
  try {
    console.log('📱 Initializing Selcom payment...');
    
    // NOTE: vendor, api_key, and secret are NOT accepted from the client.
    // They are read from server-side environment variables only.
    const {
      order_id,
      buyer_phone,
      amount,
      currency,
      payment_method,
      webhook_url,
      redirect_url,
      metadata,
    } = req.body;

    // Validate required fields
    if (!order_id || !buyer_phone || !amount) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: order_id, buyer_phone, amount',
      });
    }

    console.log('   Order ID:', order_id);
    console.log('   Phone:', buyer_phone);
    console.log('   Amount:', amount, currency);
    console.log('   Method:', payment_method);

    // Generate timestamp and signature
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = generateSelcomSignature(order_id, amount, timestamp);

    // Prepare Selcom API request.
    // SECURITY: Always use server-side vendor from .env — never trust client-sent value.
    const selcomVendor = process.env.SELCOM_VENDOR;
    if (!selcomVendor) {
      return res.status(500).json({
        success: false,
        message: 'Payment not configured. Set SELCOM_VENDOR in backend .env file.',
      });
    }
    const selcomPayload = {
      vendor: selcomVendor,
      order_id,
      buyer_phone,
      amount: parseFloat(amount),
      currency: currency || 'TZS',
      payment_method: payment_method || 'MPESA',
      webhook_url: webhook_url || `${process.env.BASE_URL}/selcom/webhook`,
      redirect_url: redirect_url || `${process.env.BASE_URL}/selcom/callback`,
      metadata: metadata || {},
      timestamp,
    };

    console.log('   Calling Selcom API...');

    // Call Selcom API
    const response = await axios.post(
      'https://apigw.selcommobile.com/v1/checkout',
      selcomPayload,
      {
        headers: {
          'X-API-Key': process.env.SELCOM_API_KEY,
          'X-Signature': signature,
          'Content-Type': 'application/json',
        },
        timeout: 30000, // 30 second timeout
      }
    );

    console.log('✅ Selcom response:', response.status);

    // Return success with payment URL
    res.json({
      success: true,
      payment_url: response.data.data?.payment_url || response.data.payment_url,
      order_id: response.data.data?.order_id || order_id,
      message: 'Payment initialized successfully',
    });

  } catch (error) {
    console.error('❌ Selcom init error:', error.response?.data || error.message);
    
    res.status(500).json({
      success: false,
      message: error.response?.data?.message || 'Payment initialization failed',
      error: error.message,
    });
  }
});

/**
 * Verify Selcom payment
 * POST /selcom/verify
 */
app.post('/selcom/verify', async (req, res) => {
  try {
    console.log('🔍 Verifying Selcom payment...');
    
    const { transaction_id } = req.body;

    if (!transaction_id) {
      return res.status(400).json({
        success: false,
        message: 'Missing transaction_id',
      });
    }

    console.log('   Transaction ID:', transaction_id);

    // Call Selcom verification API
    const response = await axios.get(
      `https://apigw.selcommobile.com/v1/checkout/${transaction_id}`,
      {
        headers: {
          'X-API-Key': process.env.SELCOM_API_KEY,
        },
        timeout: 30000,
      }
    );

    console.log('✅ Selcom verification response:', response.status);

    const paymentData = response.data.data || response.data;
    const isSuccess = paymentData.status === 'COMPLETED' || 
                     paymentData.status === 'SUCCESS';

    res.json({
      success: true,
      status: isSuccess ? 'successful' : 'failed',
      data: paymentData,
    });

  } catch (error) {
    console.error('❌ Selcom verify error:', error.response?.data || error.message);
    
    res.status(500).json({
      success: false,
      message: 'Verification failed',
      error: error.message,
    });
  }
});

/**
 * Selcom webhook handler
 * POST /selcom/webhook
 */
app.post('/selcom/webhook', async (req, res) => {
  try {
    console.log('📥 Selcom webhook received:');
    console.log(JSON.stringify(req.body, null, 2));

    const { order_id, status, payment_method, amount, metadata } = req.body;

    // Optional: verify webhook HMAC signature from Selcom for security
    // const sig = req.headers['x-signature'];
    // if (sig !== expectedSig) return res.status(401).json({ error: 'Invalid signature' });

    if (status === 'COMPLETED' || status === 'SUCCESS') {
      console.log(`✅ Payment completed for order: ${order_id}`);
      console.log(`   Amount: ${amount}, Method: ${payment_method}`);

      // Activate subscription in Supabase
      await activateSubscription(order_id, metadata);
    } else {
      console.log(`❌ Payment not completed for order: ${order_id} — status: ${status}`);
    }

    // Always respond with 200 OK to acknowledge webhook
    res.json({ received: true });

  } catch (error) {
    console.error('❌ Webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Selcom callback handler (redirects)
 * GET /selcom/callback
 */
app.get('/selcom/callback', (req, res) => {
  try {
    console.log('🔙 Selcom callback received:');
    console.log('   Query params:', req.query);

    const { order_id, status } = req.query;

    if (status === 'success' || status === 'completed') {
      res.send(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Payment Successful</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body {
              font-family: Arial, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            .container {
              text-align: center;
              background: white;
              padding: 40px;
              border-radius: 20px;
              box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }
            .icon { font-size: 64px; margin-bottom: 20px; }
            h1 { color: #10b981; margin: 0 0 10px 0; }
            p { color: #666; margin: 0 0 20px 0; }
            .order { color: #999; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="icon">✅</div>
            <h1>Payment Successful!</h1>
            <p>Your subscription has been activated.</p>
            <p class="order">Order: ${order_id}</p>
          </div>
        </body>
        </html>
      `);
    } else {
      res.send(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Payment Failed</title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body {
              font-family: Arial, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            }
            .container {
              text-align: center;
              background: white;
              padding: 40px;
              border-radius: 20px;
              box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }
            .icon { font-size: 64px; margin-bottom: 20px; }
            h1 { color: #ef4444; margin: 0 0 10px 0; }
            p { color: #666; margin: 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="icon">❌</div>
            <h1>Payment Failed</h1>
            <p>Please try again.</p>
          </div>
        </body>
        </html>
      `);
    }

  } catch (error) {
    console.error('❌ Callback error:', error);
    res.status(500).send('Error processing callback');
  }
});

// ========================================
// HEALTH CHECK
// ========================================

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'Selcom Payment Gateway',
    timestamp: new Date().toISOString(),
  });
});

app.get('/', (req, res) => {
  res.json({
    service: 'Real Estate Payment Backend - Selcom Only',
    version: '1.0.0',
    endpoints: {
      initialize: 'POST /selcom/initialize',
      verify: 'POST /selcom/verify',
      webhook: 'POST /selcom/webhook',
      callback: 'GET /selcom/callback',
      health: 'GET /health',
    },
  });
});

// ========================================
// START SERVER
// ========================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log('========================================');
  console.log('🚀 Selcom Payment Backend Started');
  console.log('========================================');
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`📱 Selcom Vendor: ${process.env.SELCOM_VENDOR || 'NOT SET'}`);
  console.log(`🔑 API Key: ${process.env.SELCOM_API_KEY ? '***' + process.env.SELCOM_API_KEY.slice(-4) : 'NOT SET'}`);
  console.log('========================================');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});