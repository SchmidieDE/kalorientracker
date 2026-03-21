const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = 3000;

// Trust proxy (behind Traefik)
app.set('trust proxy', 1);

// CORS
app.use(cors());

// Body limit for base64 images
app.use(express.json({ limit: '10mb' }));

// Rate limiting: 60 requests per hour per IP
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

// Main endpoint: Analyze food image
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

Aufgabe:
1. Identifiziere ALLE sichtbaren Lebensmittel auf dem Foto
2. Schätze die Portionsgröße basierend auf visuellen Hinweisen
3. Berechne die Nährwerte für die GESAMTE sichtbare Portion

Wichtige Regeln:
- Wenn mehrere Lebensmittel sichtbar sind, fasse sie zu EINEM Eintrag zusammen
- Gib den Namen auf Deutsch an
- Sei bei der Kalorienzahl eher konservativ-realistisch
- Die Confidence (0.0-1.0) soll widerspiegeln, wie sicher du dir bei der Identifikation bist
- Wenn das Bild kein Essen zeigt, setze confidence auf 0.0 und calories auf 0
- Gib einen kurzen, hilfreichen Ernährungstipp zum Essen

Antworte NUR im geforderten JSON-Format.`;

    const body = {
      contents: [{
        parts: [
          { text: prompt || defaultPrompt },
          { inline_data: { mime_type: 'image/jpeg', data: image } }
        ]
      }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: {
          type: 'OBJECT',
          properties: {
            name: { type: 'STRING' },
            calories: { type: 'INTEGER' },
            protein: { type: 'NUMBER' },
            carbs: { type: 'NUMBER' },
            fat: { type: 'NUMBER' },
            confidence: { type: 'NUMBER' },
            portionDescription: { type: 'STRING' },
            suggestions: { type: 'STRING' }
          },
          required: ['name', 'calories', 'protein', 'carbs', 'fat', 'confidence', 'portionDescription']
        }
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

    // Extract the nutrition result from Gemini response
    const candidates = data.candidates;
    if (!candidates || !candidates[0]?.content?.parts?.[0]?.text) {
      return res.status(502).json({ error: 'Keine Analyse-Ergebnisse' });
    }

    const resultText = candidates[0].content.parts[0].text;
    const result = JSON.parse(resultText);

    res.json(result);

  } catch (error) {
    console.error('Analysis error:', error);
    res.status(500).json({ error: 'Interner Serverfehler' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Kalorientracker API running on port ${PORT}`);
});
