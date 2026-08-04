const confidence = {
  type: "string",
  enum: ["high", "medium", "low"],
} as const;

const sourceIds = {
  type: "array",
  items: { type: "string" },
  maxItems: 12,
} as const;

const finding = {
  type: "object",
  additionalProperties: false,
  required: [
    "id",
    "title",
    "explanation",
    "action",
    "priority",
    "confidence",
    "source_ids",
  ],
  properties: {
    id: { type: "string" },
    title: { type: "string" },
    explanation: { type: "string" },
    action: { type: "string" },
    priority: {
      type: "string",
      enum: ["information", "monitor", "plan", "urgent"],
    },
    confidence,
    source_ids: sourceIds,
  },
} as const;

const advice = {
  type: "object",
  additionalProperties: false,
  required: [
    "id",
    "title",
    "explanation",
    "action",
    "confidence",
    "source_ids",
  ],
  properties: {
    id: { type: "string" },
    title: { type: "string" },
    explanation: { type: "string" },
    action: { type: "string" },
    confidence,
    source_ids: sourceIds,
  },
} as const;

export const REPORT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "report_version",
    "executive_summary",
    "maintenance",
    "usage_advice",
    "sale_analysis",
    "questions_for_professional",
    "limitations",
    "disclaimer",
  ],
  properties: {
    report_version: { type: "string", const: "1.0" },
    executive_summary: {
      type: "object",
      additionalProperties: false,
      required: ["title", "overall_status", "summary", "confidence"],
      properties: {
        title: { type: "string" },
        overall_status: {
          type: "string",
          enum: ["good", "monitor", "plan", "urgent", "insufficient_data"],
        },
        summary: { type: "string" },
        confidence,
      },
    },
    maintenance: {
      type: "object",
      additionalProperties: false,
      required: [
        "positive_findings",
        "attention_findings",
        "urgent_findings",
        "next_12_month_actions",
      ],
      properties: {
        positive_findings: {
          type: "array",
          items: finding,
          maxItems: 10,
        },
        attention_findings: {
          type: "array",
          items: finding,
          maxItems: 12,
        },
        urgent_findings: {
          type: "array",
          items: finding,
          maxItems: 8,
        },
        next_12_month_actions: {
          type: "array",
          items: finding,
          maxItems: 12,
        },
      },
    },
    usage_advice: {
      type: "array",
      items: advice,
      maxItems: 12,
    },
    sale_analysis: {
      type: "object",
      additionalProperties: false,
      required: [
        "summary",
        "reasons",
        "preparation_actions",
        "negotiation_points",
      ],
      properties: {
        summary: { type: "string" },
        reasons: {
          type: "array",
          items: { type: "string" },
          maxItems: 10,
        },
        preparation_actions: {
          type: "array",
          items: advice,
          maxItems: 12,
        },
        negotiation_points: {
          type: "array",
          items: advice,
          maxItems: 10,
        },
      },
    },
    questions_for_professional: {
      type: "array",
      items: { type: "string" },
      maxItems: 12,
    },
    limitations: {
      type: "array",
      items: { type: "string" },
      maxItems: 12,
    },
    disclaimer: {
      type: "object",
      additionalProperties: false,
      required: [
        "ai_assisted",
        "not_mechanical_diagnosis",
        "not_guaranteed_sale_price",
      ],
      properties: {
        ai_assisted: { type: "boolean", const: true },
        not_mechanical_diagnosis: { type: "boolean", const: true },
        not_guaranteed_sale_price: { type: "boolean", const: true },
      },
    },
  },
} as const;
