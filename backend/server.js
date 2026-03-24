const express = require('express');
const path = require('path');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const pg = require('pg');

const app = express();
const PORT = 3000;

// Database connection
const pool = new pg.Pool({
  connectionString: `postgresql://multihost:${process.env.POSTGRES_PASSWORD}@multihost-postgres:5432/kalorientracker`,
});

// Trust proxy (behind Traefik)
app.set('trust proxy', 1);

// CORS
app.use(cors());

// Body limit for base64 images
app.use(express.json({ limit: '10mb' }));

// Serve GGUF model files
app.use('/models', express.static(path.join(__dirname, 'models'), {
  maxAge: '7d',
  acceptRanges: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 60,
  message: { error: 'Zu viele Anfragen. Bitte warte eine Stunde.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'kalorientracker-api' });
});

// ==========================================
// PRODUCT DATABASE ENDPOINTS
// ==========================================

// Search products by name/brand (fuzzy)
app.get('/api/products/search', async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    if (!q || q.length < 2) return res.json([]);

    const result = await pool.query(`
      SELECT barcode, name, brand, category, serving_size,
             calories_100g, protein_100g, carbs_100g, fat_100g,
             sugar_100g, fiber_100g, salt_100g, image_url, source,
             similarity(name, $1) AS sim
      FROM products
      WHERE name % $1 OR brand % $1
         OR search_vector @@ plainto_tsquery('german', $1)
      ORDER BY sim DESC, calories_100g IS NOT NULL DESC
      LIMIT 10
    `, [q]);

    // Also search custom products
    const custom = await pool.query(`
      SELECT name, brand, calories as calories_100g, protein as protein_100g,
             carbs as carbs_100g, fat as fat_100g, serving_size,
             'custom' as source, confirmed,
             similarity(name, $1) AS sim
      FROM custom_products
      WHERE name % $1 OR search_vector @@ plainto_tsquery('german', $1)
      ORDER BY confirmed DESC, sim DESC
      LIMIT 5
    `, [q]);

    res.json([...result.rows, ...custom.rows]);
  } catch (err) {
    console.error('Product search error:', err.message);
    res.json([]);
  }
});

// Lookup product by barcode
app.get('/api/products/barcode/:ean', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM products WHERE barcode = $1 LIMIT 1',
      [req.params.ean]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Produkt nicht gefunden' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Barcode lookup error:', err.message);
    res.status(500).json({ error: 'Datenbankfehler' });
  }
});

// DB stats
app.get('/api/products/stats', async (req, res) => {
  try {
    const products = await pool.query('SELECT count(*) FROM products');
    const custom = await pool.query('SELECT count(*) FROM custom_products');
    res.json({
      products: parseInt(products.rows[0].count),
      custom_products: parseInt(custom.rows[0].count),
    });
  } catch (err) {
    res.json({ products: 0, custom_products: 0 });
  }
});

// ==========================================
// FOOD ANALYSIS (with DB enrichment)
// ==========================================

app.post('/api/analyze', async (req, res) => {
  try {
    const { image, prompt } = req.body;

    if (!image) {
      return res.status(400).json({ error: 'Kein Bild gesendet' });
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.error('GEMINI_API_KEY not set');
      return res.status(500).json({ error: 'Server-Konfigurationsfehler' });
    }

    const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

    const defaultPrompt = `Du bist ein erfahrener Ernährungsberater und Lebensmittelexperte.
Analysiere das Foto und identifiziere das Essen/Getränk.

WICHTIG: Nutze die Google-Suche um die EXAKTEN Nährwerte des Produkts zu finden!
Wenn du eine Marke oder ein Produkt erkennst (z.B. "Müllermilch Banane", "Weihenstephan Milch 1.5%"),
dann suche nach den offiziellen Nährwertangaben des Herstellers und verwende diese STATT zu schätzen.

Aufgabe:
1. Identifiziere das Lebensmittel auf dem Foto
2. Wenn es ein Markenprodukt ist: SUCHE die exakten Nährwerte im Internet
3. Wenn es kein Markenprodukt ist (z.B. ein Teller Pasta): Schätze basierend auf der Portion
4. Wenn du dir NICHT sicher bist (confidence < 0.8), gib 2-3 Alternativen an
5. Gib die erkannte Marke und das Produkt an

Regeln:
- Nährwerte pro sichtbare Portion (NICHT pro 100g, es sei denn die ganze Packung ist sichtbar)
- Name auf Deutsch
- Bei Markenprodukten: confidence hoch setzen wenn Nährwerte aus offizieller Quelle
- Wenn kein Essen: confidence=0.0, calories=0
- "detectedBrand": Marke/Hersteller wenn erkannt
- "detectedProduct": Vollständiger Produktname wenn erkannt

Antworte NUR im JSON-Format.`;

    const body = {
      contents: [{
        parts: [
          { text: prompt || defaultPrompt },
          { inline_data: { mime_type: 'image/jpeg', data: image } }
        ]
      }],
      tools: [{
        google_search: {}
      }],
      generationConfig: {
        temperature: 0.2,
      }
    };

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Gemini API error:', response.status, errorText);
      return res.status(502).json({ error: 'AI-Analyse fehlgeschlagen' });
    }

    const data = await response.json();
    const candidates = data.candidates;
    if (!candidates || !candidates[0]?.content?.parts) {
      return res.status(502).json({ error: 'Keine Analyse-Ergebnisse' });
    }

    // Extract text from all parts (grounding may split across parts)
    const allText = candidates[0].content.parts
      .filter(p => p.text)
      .map(p => p.text)
      .join('');

    // Extract JSON from response (may contain markdown code blocks)
    let resultText = allText;
    const jsonMatch = allText.match(/```json\s*([\s\S]*?)```/) || allText.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      resultText = jsonMatch[1] || jsonMatch[0];
    }

    let result;
    try {
      result = JSON.parse(resultText);
    } catch (e) {
      console.error('JSON parse error, raw text:', allText.substring(0, 500));
      return res.status(502).json({ error: 'Analyse-Format ungültig' });
    }

    // Ensure required fields
    result.name = result.name || 'Unbekannt';
    result.calories = parseInt(result.calories) || 0;
    result.protein = parseFloat(result.protein) || 0;
    result.carbs = parseFloat(result.carbs) || 0;
    result.fat = parseFloat(result.fat) || 0;
    result.confidence = parseFloat(result.confidence) || 0.5;
    result.portionDescription = result.portionDescription || '';

    // Log if grounding was used
    const grounding = data.candidates[0]?.groundingMetadata;
    if (grounding?.searchEntryPoint) {
      console.log('🔍 Google Search grounding used for:', result.detectedProduct || result.name);
    }

    // === DB ENRICHMENT: Try to find exact product in database ===
    const searchTerms = [
      result.detectedProduct,
      result.detectedBrand ? `${result.detectedBrand} ${result.name}` : null,
      result.name
    ].filter(Boolean);

    let dbMatch = null;
    for (const term of searchTerms) {
      try {
        const dbResult = await pool.query(`
          SELECT name, brand, calories_100g, protein_100g, carbs_100g, fat_100g,
                 serving_size, similarity(name, $1) AS sim
          FROM products
          WHERE name % $1 OR brand % $1
          ORDER BY sim DESC
          LIMIT 1
        `, [term]);
        if (dbResult.rows.length > 0 && dbResult.rows[0].sim > 0.3) {
          dbMatch = dbResult.rows[0];
          break;
        }
      } catch (e) { /* ignore search errors */ }
    }

    if (dbMatch) {
      // Enrich with exact DB values
      result.dbMatch = {
        name: dbMatch.name,
        brand: dbMatch.brand,
        calories_100g: dbMatch.calories_100g,
        protein_100g: dbMatch.protein_100g,
        carbs_100g: dbMatch.carbs_100g,
        fat_100g: dbMatch.fat_100g,
        serving_size: dbMatch.serving_size,
      };
      // If the AI portion is in ml/g, calculate exact values from per-100g data
      result.confidence = Math.max(result.confidence, 0.9); // boost confidence
    } else {
      // Save to custom_products for future reference
      try {
        await pool.query(`
          INSERT INTO custom_products (name, brand, calories, protein, carbs, fat, serving_size, search_vector)
          VALUES ($1, $2, $3, $4, $5, $6, $7, to_tsvector('german', $1 || ' ' || COALESCE($2, '')))
          ON CONFLICT DO NOTHING
        `, [result.name, result.detectedBrand || null, result.calories, result.protein, result.carbs, result.fat, result.portionDescription]);
      } catch (e) { /* ignore insert errors */ }
    }

    res.json(result);

  } catch (error) {
    console.error('Analysis error:', error);
    res.status(500).json({ error: 'Interner Serverfehler' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Kalorientracker API running on port ${PORT}`);
});
