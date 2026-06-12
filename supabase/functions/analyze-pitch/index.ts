// ─────────────────────────────────────────────────────────────────────────────
// Edge Function: analyze-pitch
//
// Analiza un video-pitch usando transcripción + LLM para devolver
// feedback accionable al candidato antes de publicar.
//
// Flujo:
//   1. Recibe video_url y duration_seconds
//   2. Descarga el audio y lo envía a Deepgram para transcripción
//   3. Analiza la transcripción con el LLM (Gemini/OpenAI)
//   4. Devuelve scores y tips en 4 categorías
//
// Variables de entorno necesarias:
//   - DEEPGRAM_API_KEY: API key de Deepgram para speech-to-text
//   - OPENAI_API_KEY (opcional): para análisis con GPT
//   - GEMINI_API_KEY (opcional): para análisis con Gemini
//
// Deploy:
//   supabase functions deploy analyze-pitch --no-verify-jwt
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface CategoryResult {
  score: number;
  tips: string[];
}

interface AnalysisResult {
  overall_score: number;
  communication: CategoryResult;
  content: CategoryResult;
  technical: CategoryResult;
  impact: CategoryResult;
  summary: string;
  top_tips: string[];
  word_count: number;
  wpm: number;
}

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { video_url, duration_seconds, language = "es" } = await req.json();

    if (!video_url) {
      return new Response(
        JSON.stringify({ error: "video_url is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const duration = duration_seconds || 30;

    // ── Step 1: Transcribe with Deepgram ──
    let transcript = "";
    let wordCount = 0;
    let wpm = 0;

    const deepgramKey = Deno.env.get("DEEPGRAM_API_KEY");

    if (deepgramKey) {
      try {
        const dgResponse = await fetch(
          "https://api.deepgram.com/v1/listen?language=" +
            language +
            "&punctuate=true&utterances=true&smart_format=true",
          {
            method: "POST",
            headers: {
              Authorization: `Token ${deepgramKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ url: video_url }),
          }
        );

        if (dgResponse.ok) {
          const dgData = await dgResponse.json();
          const channels = dgData?.results?.channels;
          if (channels && channels.length > 0) {
            const alternatives = channels[0]?.alternatives;
            if (alternatives && alternatives.length > 0) {
              transcript = alternatives[0]?.transcript || "";
              wordCount = (alternatives[0]?.words || []).length;
            }
          }
        } else {
          console.error("Deepgram error:", dgResponse.status, await dgResponse.text());
        }
      } catch (e) {
        console.error("Deepgram transcription failed:", e);
      }
    }

    // Calculate WPM
    if (wordCount > 0 && duration > 0) {
      wpm = Math.round((wordCount / duration) * 60);
    }

    // ── Step 2: Analyze with LLM (Gemini preferred, OpenAI fallback) ──
    let analysis: AnalysisResult | null = null;

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    const openaiKey = Deno.env.get("OPENAI_API_KEY");

    if (transcript && (geminiKey || openaiKey)) {
      const prompt = buildAnalysisPrompt(transcript, duration, wpm, language);

      if (geminiKey) {
        analysis = await analyzeWithGemini(geminiKey, prompt);
      }

      if (!analysis && openaiKey) {
        analysis = await analyzeWithOpenAI(openaiKey, prompt);
      }
    }

    // ── Step 3: Fallback to heuristic analysis ──
    if (!analysis) {
      analysis = analyzeHeuristically(transcript, duration, wordCount, wpm);
    }

    // Add word count and wpm
    analysis.word_count = wordCount;
    analysis.wpm = wpm;

    return new Response(JSON.stringify(analysis), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("analyze-pitch error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// LLM Analysis
// ─────────────────────────────────────────────────────────────────────────────

function buildAnalysisPrompt(
  transcript: string,
  duration: number,
  wpm: number,
  language: string
): string {
  return `Eres un coach profesional de presentaciones de video para una app de empleo llamada Mploya.

Analiza la siguiente transcripción de un video-pitch de ${duration} segundos (${wpm} palabras por minuto):

"""
${transcript}
"""

Responde en JSON con esta estructura exacta (sin markdown, solo JSON puro):
{
  "overall_score": <0-100>,
  "communication": {
    "score": <0-100>,
    "tips": ["tip1", "tip2"]
  },
  "content": {
    "score": <0-100>,
    "tips": ["tip1", "tip2"]
  },
  "technical": {
    "score": <0-100>,
    "tips": ["tip1", "tip2"]
  },
  "impact": {
    "score": <0-100>,
    "tips": ["tip1", "tip2"]
  },
  "summary": "resumen de 1-2 oraciones",
  "top_tips": ["tip prioritario 1", "tip prioritario 2", "tip prioritario 3"]
}

Criterios:
- Comunicación: velocidad del habla (ideal 130-150 wpm), claridad, uso de muletillas, estructura de oraciones
- Contenido: ¿se presentó? ¿mencionó experiencia? ¿tiene propuesta de valor? ¿call to action?
- Técnico: duración apropiada (30-60 seg ideal), estructura del discurso
- Impacto: verbos de acción, energía percibida, cierre memorable

Reglas:
- Sé constructivo, nunca destructivo
- Los tips que empiezan con "✓" son positivos (cosas que hizo bien)
- Los tips sin "✓" son mejoras sugeridas
- Responde en ${language === "es" ? "español" : "inglés"}
- Máximo 3 tips por categoría
- El summary debe ser motivador`;
}

async function analyzeWithGemini(
  apiKey: string,
  prompt: string
): Promise<AnalysisResult | null> {
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 1024,
            responseMimeType: "application/json",
          },
        }),
      }
    );

    if (!response.ok) {
      console.error("Gemini error:", response.status);
      return null;
    }

    const data = await response.json();
    const text =
      data?.candidates?.[0]?.content?.parts?.[0]?.text || "";

    // Parse JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]) as AnalysisResult;
    }
    return null;
  } catch (e) {
    console.error("Gemini analysis failed:", e);
    return null;
  }
}

async function analyzeWithOpenAI(
  apiKey: string,
  prompt: string
): Promise<AnalysisResult | null> {
  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "You are a professional video pitch coach. Always respond in valid JSON." },
          { role: "user", content: prompt },
        ],
        temperature: 0.3,
        max_tokens: 1024,
        response_format: { type: "json_object" },
      }),
    });

    if (!response.ok) {
      console.error("OpenAI error:", response.status);
      return null;
    }

    const data = await response.json();
    const text = data?.choices?.[0]?.message?.content || "";
    return JSON.parse(text) as AnalysisResult;
  } catch (e) {
    console.error("OpenAI analysis failed:", e);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heuristic Analysis (fallback when no LLM available)
// ─────────────────────────────────────────────────────────────────────────────

function analyzeHeuristically(
  transcript: string,
  duration: number,
  wordCount: number,
  wpm: number
): AnalysisResult {
  const lower = transcript.toLowerCase();

  // Communication
  let commScore = 70;
  const commTips: string[] = [];

  if (wordCount === 0) {
    commScore = 50;
    commTips.push("No pudimos detectar audio. Asegurate de hablar claro.");
  } else {
    if (wpm > 170) {
      commScore -= 15;
      commTips.push(`Hablaste a ~${wpm} palabras/min. Intentá bajar a 130-150.`);
    } else if (wpm < 90) {
      commScore -= 10;
      commTips.push(`Tu ritmo (${wpm} pal/min) es lento. Podés ser más dinámico.`);
    } else {
      commScore += 10;
      commTips.push(`✓ Buen ritmo de habla (~${wpm} pal/min).`);
    }
  }

  // Content
  let contentScore = 65;
  const contentTips: string[] = [];

  if (wordCount > 0) {
    const hasIntro = /soy |me llamo|mi nombre|hola/.test(lower);
    if (hasIntro) {
      contentScore += 10;
      contentTips.push("✓ Buena presentación inicial.");
    } else {
      contentTips.push('Arrancá presentándote: "Hola, soy..."');
    }

    const hasExp = /experiencia|trabajé|años|proyecto|logré|empresa/.test(lower);
    if (hasExp) {
      contentScore += 10;
      contentTips.push("✓ Mencionaste experiencia concreta.");
    } else {
      contentTips.push("Agregá un dato concreto de tu experiencia.");
    }

    const hasValue = /puedo aportar|me especializo|valor|diferencia/.test(lower);
    if (hasValue) {
      contentScore += 10;
      contentTips.push("✓ Tu propuesta de valor es clara.");
    } else {
      contentTips.push("Cerrá con tu propuesta de valor.");
    }
  }

  // Technical
  let techScore = 72;
  const techTips: string[] = [];
  if (duration < 15) {
    techScore -= 15;
    techTips.push(`Solo ${duration}s. Apuntá a 30-60 seg.`);
  } else if (duration > 90) {
    techScore -= 10;
    techTips.push(`${duration}s es largo. Mantené en 60 seg máx.`);
  } else {
    techScore += 5;
    techTips.push(`✓ Buena duración (${duration}s).`);
  }

  // Impact
  let impactScore = 68;
  const impactTips: string[] = [];

  if (wordCount > 0) {
    const actionWords = ["logré", "lideré", "construí", "optimicé", "implementé", "mejoré"];
    const found = actionWords.filter((w) => lower.includes(w));
    if (found.length > 0) {
      impactScore += 12;
      impactTips.push(`✓ Usaste verbos de impacto (${found.slice(0, 3).join(", ")}).`);
    } else {
      impactTips.push('Usá verbos de acción: "Logré...", "Lideré..."');
    }
  }

  const overall = Math.round(
    commScore * 0.25 + contentScore * 0.35 + techScore * 0.15 + impactScore * 0.25
  );

  // Top tips (non-positive ones first)
  const allTips = [
    ...commTips.filter((t) => !t.startsWith("✓")),
    ...contentTips.filter((t) => !t.startsWith("✓")),
    ...impactTips.filter((t) => !t.startsWith("✓")),
    ...techTips.filter((t) => !t.startsWith("✓")),
  ];

  let summary: string;
  if (overall >= 85) {
    summary = "¡Pitch excelente! Listo para captar la atención de reclutadores.";
  } else if (overall >= 70) {
    summary = "Buen pitch. Con ajustes menores podés mejorarlo aún más.";
  } else if (overall >= 50) {
    summary = "Tu pitch tiene potencial. Revisá los tips para mejorar.";
  } else {
    summary = "Te recomendamos re-grabar siguiendo los tips.";
  }

  return {
    overall_score: Math.min(Math.max(overall, 0), 100),
    communication: { score: Math.min(Math.max(commScore, 0), 100), tips: commTips },
    content: { score: Math.min(Math.max(contentScore, 0), 100), tips: contentTips },
    technical: { score: Math.min(Math.max(techScore, 0), 100), tips: techTips },
    impact: { score: Math.min(Math.max(impactScore, 0), 100), tips: impactTips },
    summary,
    top_tips: allTips.slice(0, 3),
    word_count: wordCount,
    wpm,
  };
}
