/**
 * FramesDashboard — Gerenciamento de Molduras de Perfil
 * Mesmo padrão visual do BubbleDashboard (Stark Admin Precision)
 * Dark #111214, surface #1C1E22, accent rosa #E040FB
 * DM Sans (títulos) + DM Mono (labels técnicos)
 *
 * Fluxo automatizado:
 *  1. Upload PNG/GIF/WebP animado da moldura (overlay transparente)
 *  2. Detecção automática de animação por MIME type e extensão
 *  3. Preencher nome, descrição, preço, raridade e estilo
 *  4. Preview em tempo real com avatar simulado + animação rodando
 *  5. Publicar → upload para store-assets/frames/ + insert em store_items (type=avatar_frame)
 *  6. Editar → preenche formulário com dados existentes, mantém imagem se não trocar
 *
 * asset_config gerado:
 *  { frame_url, image_url, rarity, frame_style, image_width, image_height, is_animated }
 *
 * Formatos suportados:
 *  - PNG estático (recomendado para molduras simples)
 *  - GIF animado (loops automáticos, suporte nativo no Flutter via CachedNetworkImage)
 *  - WebP animado (melhor compressão que GIF, suporte nativo no Flutter 3+)
 *  - APNG (PNG animado, suporte via flutter_cache_manager)
 */
import { useState, useRef, useCallback, useEffect } from "react";
import { supabase, StoreItem } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  Upload,
  Trash2,
  AlertCircle,
  CheckCircle2,
  Loader2,
  ImagePlus,
  Package,
  RefreshCw,
  User,
  Frame,
  Zap,
  Pencil,
  X,
} from "lucide-react";

// ─── Tipos ───────────────────────────────────────────────────────────────────

type FrameForm = {
  name: string;
  description: string;
  priceCoins: number;
  rarity: "common" | "rare" | "epic" | "legendary";
  frameStyle: "default" | "sparkle" | "fire" | "ice" | "neon" | "gold";
  isActive: boolean;
};

const RARITY_COLORS: Record<string, string> = {
  common: "#9CA3AF",
  rare: "#60A5FA",
  epic: "#A78BFA",
  legendary: "#FBBF24",
};

const FRAME_STYLE_LABELS: Record<string, string> = {
  default: "Padrão",
  sparkle: "Sparkle ✨",
  fire: "Fire 🔥",
  ice: "Ice ❄️",
  neon: "Neon 💜",
  gold: "Gold 🏆",
};

// MIME types e extensões que indicam animação
const ANIMATED_MIME_TYPES = new Set(["image/gif", "image/webp"]);
const ANIMATED_EXTENSIONS = new Set(["gif", "webp", "apng"]);

/**
 * Detecta se um arquivo é uma moldura animada.
 * Para WebP, a detecção por MIME não é suficiente (WebP pode ser estático),
 * então também verificamos a extensão como sinal de intenção do usuário.
 */
function detectIsAnimated(file: File): boolean {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  if (file.type === "image/gif") return true;
  if (ext === "gif") return true;
  if (ext === "apng") return true;
  // WebP animado: o usuário está enviando intencionalmente como animado
  if (file.type === "image/webp" && ext === "webp") {
    // Não temos como detectar WebP animado vs estático sem ler os bytes,
    // então exibimos um aviso e deixamos o usuário confirmar via toggle
    return false; // padrão false; usuário pode forçar via toggle
  }
  return false;
}

// ─── Preview de Avatar com Moldura ───────────────────────────────────────────

function AvatarPreview({
  frameUrl,
  name,
  rarity,
  isAnimated,
}: {
  frameUrl: string | null;
  name: string;
  rarity: string;
  isAnimated: boolean;
}) {
  const AVATAR_SIZE = 80;
  const FRAME_SIZE = Math.round(AVATAR_SIZE * 1.4); // 1.4× como no app Flutter

  return (
    <div className="flex flex-col items-center gap-5 p-6">
      {/* Preview principal */}
      <div className="flex flex-col items-center gap-3">
        <div className="flex items-center gap-2">
          <p
            className="text-[#4B5563] text-xs uppercase tracking-widest"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            Preview — Avatar + Moldura
          </p>
          {isAnimated && (
            <span
              className="flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded font-medium"
              style={{
                color: "#34D399",
                backgroundColor: "#34D39920",
                fontFamily: "'DM Mono', monospace",
              }}
            >
              <Zap className="w-2.5 h-2.5" />
              ANIMADO
            </span>
          )}
        </div>

        {/* Stack: avatar + frame overlay */}
        <div
          className="relative flex items-center justify-center"
          style={{ width: FRAME_SIZE, height: FRAME_SIZE }}
        >
          {/* Avatar simulado */}
          <div
            className="rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] border-2 border-[#3A3D44] flex items-center justify-center overflow-hidden"
            style={{ width: AVATAR_SIZE, height: AVATAR_SIZE }}
          >
            <User className="w-10 h-10 text-[#4B5563]" />
          </div>

          {/* Moldura overlay — PNG/GIF/WebP transparente sobreposto */}
          {frameUrl && (
            <img
              src={frameUrl}
              alt="Frame preview"
              className="absolute inset-0 w-full h-full object-contain pointer-events-none"
              style={{ width: FRAME_SIZE, height: FRAME_SIZE }}
            />
          )}

          {/* Placeholder quando não há moldura */}
          {!frameUrl && (
            <div
              className="absolute inset-0 rounded-full border-4 border-dashed border-[#2A2D34] pointer-events-none"
              style={{ width: FRAME_SIZE, height: FRAME_SIZE }}
            />
          )}
        </div>

        {/* Nome e raridade */}
        <div className="text-center">
          <p className="text-white text-sm font-semibold">
            {name || "Nova Moldura"}
          </p>
          <span
            className="text-[10px] px-2 py-0.5 rounded-full font-medium"
            style={{
              color: RARITY_COLORS[rarity] ?? RARITY_COLORS.common,
              backgroundColor:
                (RARITY_COLORS[rarity] ?? RARITY_COLORS.common) + "20",
              fontFamily: "'DM Mono', monospace",
            }}
          >
            {rarity}
          </span>
        </div>
      </div>

      {/* Exemplos de tamanho */}
      <div className="w-full border-t border-[#2A2D34] pt-4">
        <p
          className="text-[#4B5563] text-xs uppercase tracking-widest mb-3 text-center"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          Tamanhos no App
        </p>
        <div className="flex items-end justify-center gap-6">
          {[
            { label: "Chat", avatarPx: 36, scale: 1.4 },
            { label: "Perfil", avatarPx: 80, scale: 1.4 },
            { label: "Header", avatarPx: 56, scale: 1.4 },
          ].map(({ label, avatarPx, scale }) => {
            const framePx = Math.round(avatarPx * scale);
            return (
              <div key={label} className="flex flex-col items-center gap-1.5">
                <div
                  className="relative flex items-center justify-center"
                  style={{ width: framePx, height: framePx }}
                >
                  <div
                    className="rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] border border-[#3A3D44] flex items-center justify-center"
                    style={{ width: avatarPx, height: avatarPx }}
                  >
                    <User
                      style={{
                        width: avatarPx * 0.55,
                        height: avatarPx * 0.55,
                        color: "#4B5563",
                      }}
                    />
                  </div>
                  {frameUrl && (
                    <img
                      src={frameUrl}
                      alt=""
                      className="absolute inset-0 object-contain pointer-events-none"
                      style={{ width: framePx, height: framePx }}
                    />
                  )}
                </div>
                <p
                  className="text-[#4B5563] text-[10px]"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  {label}
                </p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Info técnica */}
      <div className="w-full border-t border-[#2A2D34] pt-3 space-y-0.5">
        <p
          className="text-[#4B5563] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          {isAnimated ? "overlay GIF/WebP animado" : "overlay PNG transparente"}
        </p>
        <p
          className="text-[#4B5563] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          frame_size = avatar × 1.4
        </p>
        <p
          className="text-[#4B5563] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          bucket: store-assets/frames/
        </p>
        {isAnimated && (
          <p
            className="text-[#34D399] text-xs"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            is_animated: true → Flutter renderiza loop automático
          </p>
        )}
      </div>
    </div>
  );
}

// ─── Componente principal ─────────────────────────────────────────────────────

export default function FramesDashboard() {
  // Form state
  const [form, setForm] = useState<FrameForm>({
    name: "",
    description: "",
    priceCoins: 200,
    rarity: "common",
    frameStyle: "default",
    isActive: true,
  });

  // Editing state
  const [editingFrame, setEditingFrame] = useState<StoreItem | null>(null);
  const [showForm, setShowForm] = useState(false);

  // Upload state
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageDimensions, setImageDimensions] = useState<{
    w: number;
    h: number;
  } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [isAnimated, setIsAnimated] = useState(false); // detectado ou forçado pelo usuário
  const [isWebP, setIsWebP] = useState(false); // WebP pode ser estático ou animado
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Submission state
  const [submitting, setSubmitting] = useState(false);

  // Existing frames
  const [frames, setFrames] = useState<StoreItem[]>([]);
  const [loadingFrames, setLoadingFrames] = useState(true);

  // ── Load existing frames ───────────────────────────────────────────────────

  async function loadFrames() {
    setLoadingFrames(true);
    const { data, error } = await supabase
      .from("store_items")
      .select("*")
      .eq("type", "avatar_frame")
      .order("created_at", { ascending: false });

    if (!error && data) setFrames(data as StoreItem[]);
    setLoadingFrames(false);
  }

  useEffect(() => {
    loadFrames();
  }, []);

  // ── Image handling ─────────────────────────────────────────────────────────

  function handleFile(file: File) {
    if (!file.type.startsWith("image/")) {
      toast.error("Arquivo inválido. Envie PNG, GIF ou WebP.");
      return;
    }

    const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
    const detected = detectIsAnimated(file);
    const webp = file.type === "image/webp" || ext === "webp";

    setIsAnimated(detected);
    setIsWebP(webp);

    if (detected) {
      toast.info(
        `Moldura animada detectada (${ext.toUpperCase()}). O Flutter renderizará o loop automaticamente.`,
        { duration: 4000 }
      );
    } else if (webp) {
      toast.info(
        "WebP detectado. Se for animado, ative o toggle 'Moldura Animada' abaixo.",
        { duration: 5000 }
      );
    }

    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      setImageDimensions({ w: img.width, h: img.height });
      URL.revokeObjectURL(url);
    };
    img.src = url;

    setImageFile(file);
    const reader = new FileReader();
    reader.onload = (e) => setImagePreview(e.target?.result as string);
    reader.readAsDataURL(file);
  }

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, []);

  // ── Open edit ──────────────────────────────────────────────────────────────

  function openEdit(item: StoreItem) {
    const cfg = (item.asset_config as Record<string, unknown>) ?? {};
    setEditingFrame(item);
    setForm({
      name: item.name,
      description: item.description ?? "",
      priceCoins: item.price_coins,
      rarity: ((cfg.rarity as FrameForm["rarity"]) ?? "common"),
      frameStyle: ((cfg.frame_style as FrameForm["frameStyle"]) ?? "default"),
      isActive: item.is_active,
    });
    setIsAnimated((cfg.is_animated as boolean) ?? false);
    setIsWebP(false);
    setImageFile(null);
    setImagePreview(item.preview_url ?? null);
    setImageDimensions(
      cfg.image_width && cfg.image_height
        ? { w: cfg.image_width as number, h: cfg.image_height as number }
        : null
    );
    setShowForm(true);
    // Scroll to top of form
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  // ── Cancel edit ────────────────────────────────────────────────────────────

  function cancelEdit() {
    setEditingFrame(null);
    setShowForm(false);
    setForm({
      name: "",
      description: "",
      priceCoins: 200,
      rarity: "common",
      frameStyle: "default",
      isActive: true,
    });
    setImageFile(null);
    setImagePreview(null);
    setImageDimensions(null);
    setIsAnimated(false);
    setIsWebP(false);
  }

  // ── Submit (create or update) ──────────────────────────────────────────────

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    // Ao criar, imagem é obrigatória; ao editar, pode manter a existente
    if (!editingFrame && !imageFile) {
      toast.error("Selecione uma imagem para a moldura.");
      return;
    }
    if (!form.name.trim()) {
      toast.error("Defina um nome para a moldura.");
      return;
    }

    setSubmitting(true);

    try {
      // 1. Upload da imagem (somente se um novo arquivo foi selecionado)
      let publicUrl: string | null = editingFrame?.preview_url ?? null;

      if (imageFile) {
        const ext = imageFile.name.split(".").pop()?.toLowerCase() ?? "png";
        const slug = form.name
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "_")
          .replace(/^_|_$/g, "");
        const path = `frames/${slug}_${Date.now()}.${ext}`;

        const { error: uploadError } = await supabase.storage
          .from("store-assets")
          .upload(path, imageFile, {
            contentType: imageFile.type,
            upsert: false,
          });

        if (uploadError) throw new Error(`Upload falhou: ${uploadError.message}`);

        const { data: urlData } = supabase.storage
          .from("store-assets")
          .getPublicUrl(path);
        publicUrl = urlData.publicUrl;
      }

      const imgW = imageDimensions?.w ?? 512;
      const imgH = imageDimensions?.h ?? 512;

      // 2. Montar asset_config para avatar_frame
      const assetConfig = {
        frame_url: publicUrl,
        image_url: publicUrl,
        rarity: form.rarity,
        frame_style: form.frameStyle,
        image_width: imgW,
        image_height: imgH,
        is_animated: isAnimated,
        mime_type: imageFile?.type ?? (editingFrame?.asset_config as Record<string, unknown>)?.mime_type ?? "image/png",
      };

      const payload = {
        type: "avatar_frame",
        name: form.name.trim(),
        description: form.description.trim() || null,
        preview_url: publicUrl,
        asset_url: publicUrl,
        asset_config: assetConfig,
        price_coins: form.priceCoins,
        price_real_cents: 0,
        is_premium_only: false,
        is_limited_edition: false,
        is_active: form.isActive,
        sort_order: 0,
      };

      if (editingFrame) {
        // 3a. Atualizar moldura existente
        const { error: updateError } = await supabase
          .from("store_items")
          .update(payload)
          .eq("id", editingFrame.id);

        if (updateError) throw new Error(`DB error: ${updateError.message}`);
        toast.success(`"${form.name}" atualizada com sucesso! ✨`);
      } else {
        // 3b. Inserir nova moldura
        const { error: insertError } = await supabase
          .from("store_items")
          .insert(payload);

        if (insertError) throw new Error(`DB error: ${insertError.message}`);
        const animLabel = isAnimated ? " animada" : "";
        toast.success(`"${form.name}" publicada na loja!${animLabel} 🎉`);
      }

      cancelEdit();
      loadFrames();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.error(msg);
    } finally {
      setSubmitting(false);
    }
  }

  // ── Toggle active ──────────────────────────────────────────────────────────

  async function toggleActive(item: StoreItem) {
    const { error } = await supabase
      .from("store_items")
      .update({ is_active: !item.is_active })
      .eq("id", item.id);

    if (error) {
      toast.error("Erro ao atualizar status.");
      return;
    }
    setFrames((prev) =>
      prev.map((f) =>
        f.id === item.id ? { ...f, is_active: !f.is_active } : f
      )
    );
    toast.success(
      `"${item.name}" ${!item.is_active ? "ativada" : "desativada"}.`
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  async function deleteFrame(item: StoreItem) {
    if (!confirm(`Deletar "${item.name}"? Esta ação não pode ser desfeita.`))
      return;

    const { error } = await supabase
      .from("store_items")
      .delete()
      .eq("id", item.id);

    if (error) {
      toast.error("Erro ao deletar.");
      return;
    }
    setFrames((prev) => prev.filter((f) => f.id !== item.id));
    toast.success(`"${item.name}" removida da loja.`);
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <div className="relative z-10 max-w-7xl mx-auto px-4 md:px-6 py-5 md:py-8">
      {/* ── Top: Criar / Editar moldura ── */}
      <div className="mb-8">
        <div className="flex items-center justify-between gap-2 mb-1">
          <div className="flex items-center gap-2">
            <div
              className="w-1 h-5 rounded-full"
              style={{ backgroundColor: editingFrame ? "#FBBF24" : "#E040FB" }}
            />
            <h2 className="text-lg font-bold text-white">
              {editingFrame ? `Editando: ${editingFrame.name}` : "Criar nova Moldura de Perfil"}
            </h2>
          </div>
          {editingFrame && (
            <button
              type="button"
              onClick={cancelEdit}
              className="flex items-center gap-1.5 text-xs px-3 py-1.5 rounded-md bg-[#2A2D34] text-[#9CA3AF] hover:text-white hover:bg-[#3A3D44] transition-colors"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              <X className="w-3.5 h-3.5" />
              Cancelar edição
            </button>
          )}
        </div>
        <p
          className="text-[#9CA3AF] text-sm ml-3"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          {editingFrame
            ? "Altere os campos desejados. A imagem só será substituída se você enviar um novo arquivo."
            : "Envie PNG, GIF animado ou WebP animado. Animação detectada automaticamente — o Flutter renderiza o loop nativamente."}
        </p>
      </div>

      {/* ── Aviso de edição ativa ── */}
      {editingFrame && (
        <div className="flex items-start gap-3 bg-[#FBBF24]/5 border border-[#FBBF24]/20 rounded-xl p-4 mb-6">
          <Pencil className="w-4 h-4 text-[#FBBF24] flex-shrink-0 mt-0.5" />
          <div>
            <p
              className="text-[#FBBF24] text-sm font-medium"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              Modo de edição ativo
            </p>
            <p
              className="text-[#4B5563] text-xs mt-1"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              Editando "{editingFrame.name}" (ID: {editingFrame.id.slice(0, 8)}...). Deixe o campo de imagem vazio para manter a imagem atual.
            </p>
          </div>
        </div>
      )}

      {/* ── Split layout: form | preview ── */}
      <form onSubmit={handleSubmit}>
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-4 md:gap-6 mb-6 md:mb-10">
          {/* Formulário — 3/5 */}
          <div className="lg:col-span-3 space-y-5">

            {/* Upload zone */}
            <div
              className={`border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-all duration-200 ${
                isDragging
                  ? "border-[#E040FB] bg-[#E040FB]/5"
                  : imageFile
                  ? isAnimated
                    ? "border-[#34D399]/60 bg-[#34D399]/5"
                    : "border-[#E040FB]/50 bg-[#E040FB]/5"
                  : editingFrame
                  ? "border-[#FBBF24]/30 bg-[#FBBF24]/5 hover:border-[#FBBF24]/50"
                  : "border-[#2A2D34] bg-[#1C1E22] hover:border-[#E040FB]/40 hover:bg-[#E040FB]/5"
              }`}
              onClick={() => fileInputRef.current?.click()}
              onDragOver={(e) => {
                e.preventDefault();
                setIsDragging(true);
              }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={onDrop}
            >
              <input
                ref={fileInputRef}
                type="file"
                accept="image/png,image/gif,image/webp,image/apng,.apng"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) handleFile(f);
                }}
              />

              {imagePreview ? (
                <div className="flex items-center gap-4">
                  {/* Preview com fundo quadriculado para mostrar transparência */}
                  <div
                    className="w-16 h-16 rounded-lg border overflow-hidden flex items-center justify-center flex-shrink-0 relative"
                    style={{
                      borderColor: isAnimated ? "#34D39940" : editingFrame && !imageFile ? "#FBBF2440" : "#2A2D34",
                      backgroundImage:
                        "linear-gradient(45deg, #2A2D34 25%, transparent 25%), linear-gradient(-45deg, #2A2D34 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #2A2D34 75%), linear-gradient(-45deg, transparent 75%, #2A2D34 75%)",
                      backgroundSize: "8px 8px",
                      backgroundPosition: "0 0, 0 4px, 4px -4px, -4px 0px",
                    }}
                  >
                    <img
                      src={imagePreview}
                      alt="Preview"
                      className="w-full h-full object-contain"
                    />
                    {/* Badge animado */}
                    {isAnimated && (
                      <div className="absolute bottom-0.5 right-0.5 bg-[#34D399] rounded-sm px-1 flex items-center gap-0.5">
                        <Zap
                          style={{ width: 8, height: 8, color: "#111214" }}
                        />
                        <span
                          style={{
                            fontSize: 8,
                            color: "#111214",
                            fontFamily: "'DM Mono', monospace",
                            fontWeight: 700,
                          }}
                        >
                          GIF
                        </span>
                      </div>
                    )}
                    {/* Badge de imagem atual (edição sem novo upload) */}
                    {editingFrame && !imageFile && (
                      <div className="absolute bottom-0.5 right-0.5 bg-[#FBBF24] rounded-sm px-1 flex items-center gap-0.5">
                        <span
                          style={{
                            fontSize: 7,
                            color: "#111214",
                            fontFamily: "'DM Mono', monospace",
                            fontWeight: 700,
                          }}
                        >
                          ATUAL
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="text-left">
                    <div className="flex items-center gap-2">
                      <p className="text-white font-medium text-sm">
                        {imageFile ? imageFile.name : "Imagem atual"}
                      </p>
                      {isAnimated && (
                        <span
                          className="text-[10px] px-1.5 py-0.5 rounded font-medium"
                          style={{
                            color: "#34D399",
                            backgroundColor: "#34D39920",
                            fontFamily: "'DM Mono', monospace",
                          }}
                        >
                          ANIMADO
                        </span>
                      )}
                    </div>
                    <p
                      className="text-[#9CA3AF] text-xs mt-0.5"
                      style={{ fontFamily: "'DM Mono', monospace" }}
                    >
                      {imageDimensions
                        ? `${imageDimensions.w}×${imageDimensions.h}px`
                        : "Dimensões não disponíveis"}
                      {imageDimensions &&
                        imageDimensions.w !== imageDimensions.h && (
                          <span className="text-yellow-400 ml-2">
                            ⚠ Recomendado: quadrado
                          </span>
                        )}
                    </p>
                    <p
                      className="text-xs mt-1"
                      style={{ color: editingFrame ? "#FBBF24" : "#E040FB" }}
                    >
                      {editingFrame && !imageFile
                        ? "Clique para substituir a imagem"
                        : "Clique para trocar"}
                    </p>
                  </div>
                </div>
              ) : (
                <div>
                  <Frame className="w-8 h-8 text-[#4B5563] mx-auto mb-2" />
                  <p className="text-[#9CA3AF] text-sm">
                    Arraste ou clique para enviar
                  </p>
                  <p
                    className="text-[#4B5563] text-xs mt-1"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    PNG estático · GIF animado · WebP animado
                  </p>
                </div>
              )}
            </div>

            {/* Toggle: Moldura Animada — visível para WebP (ambíguo) ou quando não detectado */}
            {(imageFile || editingFrame) && (isWebP || !isAnimated) && (
              <div
                className="flex items-start gap-3 bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4"
                style={{ borderColor: isAnimated ? "#34D39940" : undefined }}
              >
                <button
                  type="button"
                  onClick={() => setIsAnimated((v) => !v)}
                  className={`relative w-10 h-5 rounded-full transition-colors duration-200 flex-shrink-0 mt-0.5 ${
                    isAnimated ? "bg-[#34D399]" : "bg-[#2A2D34]"
                  }`}
                >
                  <span
                    className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200 ${
                      isAnimated ? "translate-x-5" : "translate-x-0.5"
                    }`}
                  />
                </button>
                <div>
                  <div className="flex items-center gap-2">
                    <Zap
                      className="w-3.5 h-3.5"
                      style={{ color: isAnimated ? "#34D399" : "#4B5563" }}
                    />
                    <span
                      className="text-sm font-medium"
                      style={{
                        color: isAnimated ? "#34D399" : "#9CA3AF",
                        fontFamily: "'DM Mono', monospace",
                      }}
                    >
                      Moldura Animada
                    </span>
                  </div>
                  <p
                    className="text-[#4B5563] text-xs mt-1"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    {isWebP
                      ? "WebP pode ser estático ou animado. Ative se o arquivo contém animação."
                      : "Ative para marcar esta moldura como animada no asset_config."}
                  </p>
                </div>
              </div>
            )}

            {/* Banner informativo quando GIF é detectado automaticamente */}
            {imageFile && isAnimated && !isWebP && (
              <div className="flex items-start gap-3 bg-[#34D399]/5 border border-[#34D399]/20 rounded-xl p-4">
                <Zap className="w-4 h-4 text-[#34D399] flex-shrink-0 mt-0.5" />
                <div>
                  <p
                    className="text-[#34D399] text-sm font-medium"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    Animação detectada automaticamente
                  </p>
                  <p
                    className="text-[#4B5563] text-xs mt-1"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    O Flutter renderiza GIF/WebP animado nativamente via
                    CachedNetworkImage. O loop é automático e não requer
                    configuração adicional.
                  </p>
                </div>
              </div>
            )}

            {/* Nome */}
            <div className="space-y-1.5">
              <Label
                className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Nome da Moldura *
              </Label>
              <Input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Ex: Golden Crown, Neon Halo..."
                required
                className="bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] h-10"
              />
            </div>

            {/* Descrição */}
            <div className="space-y-1.5">
              <Label
                className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Descrição (opcional)
              </Label>
              <Input
                value={form.description}
                onChange={(e) =>
                  setForm({ ...form, description: e.target.value })
                }
                placeholder="Descrição breve para a loja..."
                className="bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] h-10"
              />
            </div>

            {/* Preço + Raridade */}
            <div className="grid grid-cols-2 gap-2 md:gap-4">
              <div className="space-y-1.5">
                <Label
                  className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  Preço (coins) *
                </Label>
                <Input
                  type="number"
                  min={0}
                  value={form.priceCoins}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      priceCoins: parseInt(e.target.value) || 0,
                    })
                  }
                  className="bg-[#1C1E22] border-[#2A2D34] text-white focus:border-[#E040FB] h-10"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                />
              </div>

              <div className="space-y-1.5">
                <Label
                  className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  Raridade
                </Label>
                <select
                  value={form.rarity}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      rarity: e.target.value as FrameForm["rarity"],
                    })
                  }
                  className="w-full h-10 rounded-md bg-[#1C1E22] border border-[#2A2D34] text-white px-3 text-sm focus:border-[#E040FB] focus:outline-none"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  <option value="common">Common</option>
                  <option value="rare">Rare</option>
                  <option value="epic">Epic</option>
                  <option value="legendary">Legendary</option>
                </select>
              </div>
            </div>

            {/* Estilo da moldura */}
            <div className="space-y-1.5">
              <Label
                className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Estilo / Efeito
              </Label>
              <select
                value={form.frameStyle}
                onChange={(e) =>
                  setForm({
                    ...form,
                    frameStyle: e.target.value as FrameForm["frameStyle"],
                  })
                }
                className="w-full h-10 rounded-md bg-[#1C1E22] border border-[#2A2D34] text-white px-3 text-sm focus:border-[#E040FB] focus:outline-none"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {Object.entries(FRAME_STYLE_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </select>
              <p
                className="text-[#4B5563] text-xs"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Salvo em asset_config.frame_style — usado pelo app para efeitos
                especiais
              </p>
            </div>

            {/* Status */}
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() =>
                  setForm({ ...form, isActive: !form.isActive })
                }
                className={`relative w-10 h-5 rounded-full transition-colors duration-200 ${
                  form.isActive ? "bg-[#E040FB]" : "bg-[#2A2D34]"
                }`}
              >
                <span
                  className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200 ${
                    form.isActive ? "translate-x-5" : "translate-x-0.5"
                  }`}
                />
              </button>
              <span
                className="text-[#9CA3AF] text-sm"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {form.isActive
                  ? "Publicar na loja imediatamente"
                  : "Salvar como rascunho"}
              </span>
            </div>

            {/* Botões de ação */}
            <div className="flex gap-3">
              <Button
                type="submit"
                disabled={submitting || (!editingFrame && !imageFile) || !form.name.trim()}
                className="flex-1 h-11 text-white font-semibold border-0 transition-all duration-200 disabled:opacity-40"
                style={{
                  backgroundColor: editingFrame ? "#FBBF24" : "#E040FB",
                }}
              >
                {submitting ? (
                  <span className="flex items-center gap-2">
                    <Loader2 className="w-4 h-4 animate-spin" />
                    {editingFrame ? "Salvando..." : "Publicando..."}
                  </span>
                ) : editingFrame ? (
                  <span className="flex items-center gap-2">
                    <Pencil className="w-4 h-4" />
                    Salvar Alterações
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    <Upload className="w-4 h-4" />
                    Publicar na Loja
                    {isAnimated && (
                      <span
                        className="text-[10px] px-1.5 py-0.5 rounded font-medium ml-1"
                        style={{
                          color: "#34D399",
                          backgroundColor: "#34D39930",
                          fontFamily: "'DM Mono', monospace",
                        }}
                      >
                        ANIMADA
                      </span>
                    )}
                  </span>
                )}
              </Button>
              {editingFrame && (
                <Button
                  type="button"
                  onClick={cancelEdit}
                  variant="ghost"
                  className="h-11 px-4 text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] border border-[#2A2D34]"
                >
                  <X className="w-4 h-4 mr-1.5" />
                  Cancelar
                </Button>
              )}
            </div>
          </div>

          {/* Preview — 2/5 */}
          <div className="lg:col-span-2">
            <div
              className="border rounded-xl overflow-hidden lg:sticky lg:top-6"
              style={{
                backgroundColor: "#1C1E22",
                borderColor: editingFrame
                  ? "#FBBF2430"
                  : isAnimated
                  ? "#34D39930"
                  : "#2A2D34",
              }}
            >
              {/* Preview header */}
              <div
                className="px-4 py-3 border-b flex items-center gap-2"
                style={{
                  borderColor: editingFrame
                    ? "#FBBF2430"
                    : isAnimated
                    ? "#34D39930"
                    : "#2A2D34",
                }}
              >
                <User
                  className="w-4 h-4"
                  style={{
                    color: editingFrame ? "#FBBF24" : isAnimated ? "#34D399" : "#E040FB",
                  }}
                />
                <span
                  className="text-xs uppercase tracking-widest"
                  style={{
                    color: "#9CA3AF",
                    fontFamily: "'DM Mono', monospace",
                  }}
                >
                  Preview em tempo real
                </span>
                {editingFrame && (
                  <span
                    className="ml-auto flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded font-medium"
                    style={{
                      color: "#FBBF24",
                      backgroundColor: "#FBBF2420",
                      fontFamily: "'DM Mono', monospace",
                    }}
                  >
                    <Pencil className="w-2.5 h-2.5" />
                    EDITANDO
                  </span>
                )}
                {!editingFrame && isAnimated && (
                  <span
                    className="ml-auto flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded font-medium"
                    style={{
                      color: "#34D399",
                      backgroundColor: "#34D39920",
                      fontFamily: "'DM Mono', monospace",
                    }}
                  >
                    <Zap className="w-2.5 h-2.5" />
                    ANIMADO
                  </span>
                )}
              </div>

              {/* Avatar simulation */}
              <div className="bg-[#111214]">
                <AvatarPreview
                  frameUrl={imagePreview}
                  name={form.name}
                  rarity={form.rarity}
                  isAnimated={isAnimated}
                />
              </div>
            </div>
          </div>
        </div>
      </form>

      {/* ── Lista de molduras existentes ── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <div className="w-1 h-5 bg-[#E040FB] rounded-full" />
            <h2 className="text-lg font-bold text-white">
              Molduras na Loja
            </h2>
            <span
              className="text-[#4B5563] text-sm"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              ({frames.length})
            </span>
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={loadFrames}
            className="text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-8 px-2"
          >
            <RefreshCw className="w-3.5 h-3.5" />
          </Button>
        </div>

        {loadingFrames ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
          </div>
        ) : frames.length === 0 ? (
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-10 text-center">
            <Package className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
            <p className="text-[#4B5563] text-sm">
              Nenhuma moldura na loja ainda.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {frames.map((item) => {
              const cfg = item.asset_config as Record<string, unknown>;
              const rarity = (cfg?.rarity as string) ?? "common";
              const frameStyle = (cfg?.frame_style as string) ?? "default";
              const frameIsAnimated = (cfg?.is_animated as boolean) ?? false;
              const frameUrl =
                (cfg?.frame_url as string) ||
                item.preview_url ||
                null;
              const isEditing = editingFrame?.id === item.id;

              return (
                <div
                  key={item.id}
                  className={`bg-[#1C1E22] border rounded-xl overflow-hidden transition-all duration-200 ${
                    isEditing
                      ? "border-[#FBBF24]/50 ring-1 ring-[#FBBF24]/20"
                      : item.is_active
                      ? frameIsAnimated
                        ? "border-[#34D399]/20 hover:border-[#34D399]/40"
                        : "border-[#2A2D34] hover:border-[#E040FB]/30"
                      : "border-[#2A2D34] opacity-50"
                  }`}
                >
                  {/* Top accent bar com cor da raridade */}
                  <div
                    className="h-1 w-full"
                    style={{
                      backgroundColor: isEditing
                        ? "#FBBF24"
                        : RARITY_COLORS[rarity] ?? RARITY_COLORS.common,
                    }}
                  />

                  <div className="p-4">
                    {/* Preview com avatar simulado */}
                    <div className="w-16 h-16 rounded-lg bg-[#111214] border border-[#2A2D34] mb-3 overflow-hidden flex items-center justify-center relative">
                      {/* Avatar mini */}
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] flex items-center justify-center">
                        <User className="w-5 h-5 text-[#4B5563]" />
                      </div>
                      {/* Frame overlay — GIF animará automaticamente no browser */}
                      {frameUrl ? (
                        <img
                          src={frameUrl}
                          alt={item.name}
                          className="absolute inset-0 w-full h-full object-contain pointer-events-none"
                        />
                      ) : (
                        <ImagePlus className="w-6 h-6 text-[#4B5563] absolute" />
                      )}
                      {/* Badge animado no card */}
                      {frameIsAnimated && (
                        <div
                          className="absolute top-0.5 right-0.5 flex items-center gap-0.5 px-1 rounded-sm"
                          style={{ backgroundColor: "#34D399" }}
                        >
                          <Zap
                            style={{ width: 7, height: 7, color: "#111214" }}
                          />
                        </div>
                      )}
                    </div>

                    {/* Name + rarity + animated badge */}
                    <div className="flex items-start justify-between gap-2 mb-1">
                      <p className="text-white font-semibold text-sm leading-tight">
                        {item.name}
                      </p>
                      <div className="flex flex-col items-end gap-1 shrink-0">
                        <span
                          className="text-[10px] px-1.5 py-0.5 rounded font-medium"
                          style={{
                            color:
                              RARITY_COLORS[rarity] ?? RARITY_COLORS.common,
                            backgroundColor:
                              (RARITY_COLORS[rarity] ?? RARITY_COLORS.common) +
                              "20",
                            fontFamily: "'DM Mono', monospace",
                          }}
                        >
                          {rarity}
                        </span>
                        {frameIsAnimated && (
                          <span
                            className="flex items-center gap-0.5 text-[9px] px-1.5 py-0.5 rounded font-medium"
                            style={{
                              color: "#34D399",
                              backgroundColor: "#34D39920",
                              fontFamily: "'DM Mono', monospace",
                            }}
                          >
                            <Zap style={{ width: 8, height: 8 }} />
                            anim
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Style tag */}
                    <p
                      className="text-[#6B7280] text-[10px] mb-1"
                      style={{ fontFamily: "'DM Mono', monospace" }}
                    >
                      {FRAME_STYLE_LABELS[frameStyle] ?? frameStyle}
                    </p>

                    {/* Price */}
                    <p
                      className="text-[#9CA3AF] text-xs mb-3"
                      style={{ fontFamily: "'DM Mono', monospace" }}
                    >
                      {item.price_coins} coins
                    </p>

                    {/* Actions */}
                    <div className="flex items-center gap-2">
                      {/* Botão Editar */}
                      <button
                        onClick={() => openEdit(item)}
                        className={`flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-md transition-colors ${
                          isEditing
                            ? "bg-[#FBBF24]/20 text-[#FBBF24]"
                            : "bg-[#2A2D34] text-[#9CA3AF] hover:bg-[#3A3D44] hover:text-white"
                        }`}
                        style={{ fontFamily: "'DM Mono', monospace" }}
                      >
                        <Pencil className="w-3 h-3" />
                        {isEditing ? "Editando" : "Editar"}
                      </button>

                      {/* Botão Ativar/Desativar */}
                      <button
                        onClick={() => toggleActive(item)}
                        className={`flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-md transition-colors ${
                          item.is_active
                            ? "bg-green-500/10 text-green-400 hover:bg-green-500/20"
                            : "bg-[#2A2D34] text-[#9CA3AF] hover:bg-[#3A3D44]"
                        }`}
                        style={{ fontFamily: "'DM Mono', monospace" }}
                      >
                        {item.is_active ? (
                          <>
                            <CheckCircle2 className="w-3 h-3" />
                            Ativa
                          </>
                        ) : (
                          <>
                            <AlertCircle className="w-3 h-3" />
                            Inativa
                          </>
                        )}
                      </button>

                      {/* Botão Deletar */}
                      <button
                        onClick={() => deleteFrame(item)}
                        className="ml-auto p-1.5 rounded-md text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
