export type JsonMap = Record<string, unknown>;

export type ParkingStatus =
  | "open"
  | "closed"
  | "full"
  | "unavailable"
  | "unknown";

export type ParkingConfidence =
  | "official_realtime"
  | "official_stale"
  | "official_static"
  | "osm";

export type ParkingResult = {
  parking_id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  distance_km: number;
  parking_type: string;
  access: string;
  fee: "free" | "paid" | "unknown";
  charge: string | null;
  capacity: number | null;
  available_spaces: number | null;
  predicted_available_spaces: number | null;
  prediction_samples: number | null;
  disabled_spaces: number | null;
  charging_spaces: number | null;
  park_and_ride: boolean;
  covered: boolean;
  opening_hours: string | null;
  operator: string | null;
  website: string | null;
  phone: string | null;
  max_height_m: number | null;
  surface: string | null;
  source_kind: "facility" | "entrance" | "official";
  availability_status: ParkingStatus;
  realtime: boolean;
  confidence: ParkingConfidence;
  availability_updated_at: string | null;
  availability_source: string | null;
  provider_code: string | null;
  external_id: string | null;
  smart_score: number;
  recommendation_rank: number;
  recommendation_reasons: string[];
};

export type ProviderSummary = {
  code: string;
  name: string;
  status: "ok" | "error" | "skipped";
  records: number;
  realtime: boolean;
  message?: string;
};

export type ProviderFetchResult = {
  results: ParkingResult[];
  summaries: ProviderSummary[];
};

export type Prediction = {
  available: number;
  samples: number;
};
