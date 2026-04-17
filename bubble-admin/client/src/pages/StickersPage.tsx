import { useState, useEffect, useRef } from "react";
import { supabase, StickerPack, Sticker } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  Plus,
  Trash2,
  Pencil,
  CheckCircle2,
  AlertCircle,
  Loader2,
  RefreshCw,
  Search,
  Upload,
  X,
  Save,
  ChevronLeft,
  Package,
  Image,
  ArrowUpDown,
} from "lucide-react";

type PackForm = {
  name: string;
  description: string;
  author_name: string;
  price_coins: number;
  is_free: boolean;
  is_premium_only: boolean;
  is_active: boolean;
  sort_order: number;
  tags: string;
};

const DEFAULT_PACK_FORM: PackForm = {
  name: "",
  description: "",
  author_name: "NexusHub",
  price_coins: 0,
  is_free: true,
  is_premium_only: false,
  is_active: true,
  sort_order: 0,
  tags: "",
};

export default function StickersPage() {
  const [packs, setPacks] = useState<StickerPack[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  // Selected pack for sticker management
  const [selectedPack, setSelectedPack] = useState<StickerPack | null>(null);
  const [stickers, setStickers] = useState<Sticker[]>([]);
  const [loadingStickers, setLoadingStickers] = useState(false);

  // Pack form
  const [showPackForm, setShowPackForm] = useState(false);
  const [editingPack, setEditingPack] = useState<StickerPack | null>(null);
  const [packForm, setPackForm] = useState<PackForm>(DEFAULT_PACK_FORM);
  const [submittingPack, setSubmittingPack] = useState(false);
  const [iconFile, setIconFile] = useState<File | null>(null);
  const [iconPreview, setIconPreview] = useState<string | null>(null);
  const iconInputRef = useRef<HTMLInputElement>(null);

  // Sticker upload
  const [uploadingStickers, setUploadingStickers] = useState(false);
  const stickerInputRef = useRef<HTMLInputElement>(null);

  async function loadPacks() {
    setLoading(true);
    const { data, error } = await supabase
      .from("sticker_packs")
      .select("*")
      .eq("is_user_created", false)
      .order("sort_order", { ascending: true });
    if (!error && data) setPacks(data as StickerPack[]);
    setLoading(false);
  }

  async function loadStickers(packId: string) {
    setLoadingStickers(true);
    const { data, error } = await supabase
      .from("stickers")
      .select("*")
      .eq("pack_id", packId)
      .order("sort_order", { ascending: true });
    if (!error && data) setStickers(data as Sticker[]);
    setLoadingStickers(false);
  }

  useEffect(() => {
    loadPacks();
  }, []);

  function openCreatePack() {
    setEditingPack(null);
    setPackForm(DEFAULT_PACK_FORM);
    setIconFile(null);
    setIconPreview(null);
    setShowPackForm(true);
  }

  function openEditPack(pack: StickerPack) {
    setEditingPack(pack);
    setPackForm({
      name: pack.name,
      description: pack.description,
      author_name: pack.author_name,
      price_coins: pack.price_coins,
      is_free: pack.is_free,
      is_premium_only: pack.is_premium_only,
      is_active: pack.is_active,
      sort_order: pack.sort_order,
      tags: (pack.tags ?? []).join(", "),
    });
    setIconPreview(pack.icon_url);
    setIconFile(null);
    setShowPackForm(true);
  }

  async function uploadFile(file: File, path: string): Promise<string | null> {
    const { data, error } = await supabase.storage
      .from("store-assets")
      .upload(path, file, { upsert: true });
    if (error) {
      toast.error(`Erro no upload: ${error.message}`);
      return null;
    }
    const { data: urlData } = supabase.storage
      .from("store-assets")
      .getPublicUrl(data.path);
    return urlData.publicUrl;
  }

  async function handleSubmitPack(e: React.FormEvent) {
    e.preventDefault();
    if (!packForm.name.trim()) {
      toast.error("Nome é obrigatório.");
      return;
    }
    setSubmittingPack(true);
    try {
      let finalIconUrl = iconPreview;

      if (iconFile) {
        const ext = iconFile.name.split(".").pop();
        const path = `sticker-packs/icons/${Date.now()}_${packForm.name.replace(/\s+/g, "_")}.${ext}`;
        finalIconUrl = await uploadFile(iconFile, path);
        if (!finalIconUrl) return;
      }

      const payload = {
        name: packForm.name.trim(),
        description: packForm.description.trim(),
        author_name: packForm.author_name.trim(),
        price_coins: packForm.price_coins,
        is_free: packForm.is_free,
        is_premium_only: packForm.is_premium_only,
        is_active: packForm.is_active,
        sort_order: packForm.sort_order,
        tags: packForm.tags
          .split(",")
          .map((t) => t.trim())
          .filter(Boolean),
        icon_url: finalIconUrl,
        is_user_created: false,
        is_public: true,
      };

      if (editingPack) {
        const { error } = await supabase
          .from("sticker_packs")
          .update(payload)
          .eq("id", editingPack.id);
        if (error) throw error;
        toast.success("Pack atualizado!");
      } else {
        const { error } = await supabase
          .from("sticker_packs")
          .insert(payload);
        if (error) throw error;
        toast.success("Pack criado!");
      }

      setShowPackForm(false);
      loadPacks();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.error(`Erro: ${msg}`);
    } finally {
      setSubmittingPack(false);
    }
  }

  async function deletePack(pack: StickerPack) {
    if (!confirm(`Excluir o pack "${pack.name}" e todos os seus stickers?`))
      return;
    const { error } = await supabase
      .from("sticker_packs")
      .delete()
      .eq("id", pack.id);
    if (error) {
      toast.error("Erro ao excluir pack.");
    } else {
      toast.success("Pack excluído.");
      if (selectedPack?.id === pack.id) setSelectedPack(null);
      loadPacks();
    }
  }

  async function togglePackActive(pack: StickerPack) {
    const { error } = await supabase
      .from("sticker_packs")
      .update({ is_active: !pack.is_active })
      .eq("id", pack.id);
    if (error) {
      toast.error("Erro ao alterar status.");
    } else {
      toast.success(pack.is_active ? "Pack desativado." : "Pack ativado!");
      loadPacks();
    }
  }

  function selectPack(pack: StickerPack) {
    setSelectedPack(pack);
    loadStickers(pack.id);
  }

  async function uploadStickers(files: FileList) {
    if (!selectedPack) return;
    setUploadingStickers(true);
    let successCount = 0;
    let errorCount = 0;

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (!file.type.startsWith("image/")) continue;

      const ext = file.name.split(".").pop();
      const baseName = file.name.replace(/\.[^.]+$/, "");
      const path = `stickers/${selectedPack.id}/${Date.now()}_${i}.${ext}`;

      const url = await uploadFile(file, path);
      if (!url) {
        errorCount++;
        continue;
      }

      const isAnimated =
        ext === "gif" || ext === "apng" || ext === "webp";

      const { error } = await supabase.from("stickers").insert({
        pack_id: selectedPack.id,
        name: baseName,
        image_url: url,
        is_animated: isAnimated,
        sort_order: stickers.length + i,
      });

      if (error) {
        errorCount++;
      } else {
        successCount++;
      }
    }

    // Update sticker_count
    await supabase
      .from("sticker_packs")
      .update({ sticker_count: stickers.length + successCount })
      .eq("id", selectedPack.id);

    if (successCount > 0)
      toast.success(`${successCount} sticker(s) adicionado(s)!`);
    if (errorCount > 0)
      toast.error(`${errorCount} sticker(s) com erro.`);

    loadStickers(selectedPack.id);
    loadPacks();
    setUploadingStickers(false);
  }

  async function deleteSticker(sticker: Sticker) {
    const { error } = await supabase
      .from("stickers")
      .delete()
      .eq("id", sticker.id);
    if (error) {
      toast.error("Erro ao excluir sticker.");
    } else {
      toast.success("Sticker excluído.");
      if (selectedPack) {
        await supabase
          .from("sticker_packs")
          .update({ sticker_count: Math.max(0, stickers.length - 1) })
          .eq("id", selectedPack.id);
        loadStickers(selectedPack.id);
        loadPacks();
      }
    }
  }

  const filteredPacks = packs.filter(
    (p) =>
      !search ||
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      p.description.toLowerCase().includes(search.toLowerCase())
  );

  // Sticker management view
  if (selectedPack) {
    return (
      <div className="p-6 max-w-7xl mx-auto">
        <div className="flex items-center gap-3 mb-6">
          <button
            onClick={() => setSelectedPack(null)}
            className="p-1.5 rounded-md text-[#6B7280] hover:text-white hover:bg-[#2A2D34] transition-colors"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <div className="flex items-center gap-3">
            {selectedPack.icon_url && (
              <img
                src={selectedPack.icon_url}
                alt={selectedPack.name}
                className="w-10 h-10 rounded-xl object-cover"
              />
            )}
            <div>
              <h1 className="text-xl font-bold text-white">
                {selectedPack.name}
              </h1>
              <p className="text-[#6B7280] text-sm">
                {stickers.length} stickers · {selectedPack.price_coins} coins
              </p>
            </div>
          </div>
          <div className="ml-auto flex gap-2">
            <Button
              onClick={() => stickerInputRef.current?.click()}
              disabled={uploadingStickers}
              className="bg-[#E040FB] hover:bg-[#D030EB] text-white h-9 px-4 text-sm"
            >
              {uploadingStickers ? (
                <Loader2 className="w-4 h-4 animate-spin mr-1.5" />
              ) : (
                <Upload className="w-4 h-4 mr-1.5" />
              )}
              Adicionar Stickers
            </Button>
            <input
              ref={stickerInputRef}
              type="file"
              accept="image/*"
              multiple
              className="hidden"
              onChange={(e) => {
                if (e.target.files?.length) uploadStickers(e.target.files);
              }}
            />
          </div>
        </div>

        {loadingStickers ? (
          <div className="flex items-center justify-center h-48">
            <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
          </div>
        ) : stickers.length === 0 ? (
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-12 text-center">
            <Image className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
            <p className="text-[#4B5563] text-sm mb-3">
              Nenhum sticker neste pack
            </p>
            <Button
              onClick={() => stickerInputRef.current?.click()}
              className="bg-[#E040FB] hover:bg-[#D030EB] text-white h-9 px-4 text-sm"
            >
              <Upload className="w-4 h-4 mr-1.5" />
              Adicionar Stickers
            </Button>
          </div>
        ) : (
          <div className="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 lg:grid-cols-10 gap-3">
            {stickers.map((sticker) => (
              <div
                key={sticker.id}
                className="group relative bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden aspect-square"
              >
                <img
                  src={sticker.image_url}
                  alt={sticker.name}
                  className="w-full h-full object-cover"
                />
                <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1">
                  <button
                    onClick={() => deleteSticker(sticker)}
                    className="p-1.5 rounded-md bg-red-500/20 text-red-400 hover:bg-red-500/40 transition-colors"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
                {sticker.is_animated && (
                  <div className="absolute top-1 right-1 bg-[#E040FB]/80 text-white text-[9px] px-1 rounded">
                    GIF
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-white">Packs de Stickers</h1>
          <p className="text-[#6B7280] text-sm mt-0.5">
            {packs.length} packs oficiais
          </p>
        </div>
        <Button
          onClick={openCreatePack}
          className="bg-[#E040FB] hover:bg-[#D030EB] text-white h-9 px-4 text-sm"
        >
          <Plus className="w-4 h-4 mr-1.5" />
          Novo Pack
        </Button>
      </div>

      {/* Search */}
      <div className="flex gap-3 mb-5">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#4B5563]" />
          <Input
            placeholder="Buscar packs..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
          />
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={loadPacks}
          className="text-[#6B7280] hover:text-white hover:bg-[#2A2D34] h-9"
        >
          <RefreshCw className="w-3.5 h-3.5" />
        </Button>
      </div>

      {/* Packs grid */}
      {loading ? (
        <div className="flex items-center justify-center h-48">
          <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
        </div>
      ) : filteredPacks.length === 0 ? (
        <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-12 text-center">
          <Package className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
          <p className="text-[#4B5563] text-sm">Nenhum pack encontrado</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredPacks.map((pack) => (
            <div
              key={pack.id}
              className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-4 flex flex-col gap-3 hover:border-[#3A3D44] transition-colors"
            >
              <div className="flex items-start gap-3">
                <div
                  className="w-12 h-12 rounded-xl bg-[#111214] border border-[#2A2D34] flex items-center justify-center flex-shrink-0 overflow-hidden cursor-pointer"
                  onClick={() => selectPack(pack)}
                >
                  {pack.icon_url ? (
                    <img
                      src={pack.icon_url}
                      alt={pack.name}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <Package className="w-5 h-5 text-[#4B5563]" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <h3
                    className="text-white font-medium text-sm cursor-pointer hover:text-[#E040FB] transition-colors truncate"
                    onClick={() => selectPack(pack)}
                  >
                    {pack.name}
                  </h3>
                  <p className="text-[#6B7280] text-xs truncate">
                    {pack.description || "Sem descrição"}
                  </p>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-[#FBBF24] text-xs">
                      {pack.price_coins} coins
                    </span>
                    <span className="text-[#4B5563] text-xs">·</span>
                    <span className="text-[#6B7280] text-xs">
                      {pack.sticker_count} stickers
                    </span>
                  </div>
                </div>
              </div>

              {pack.tags?.length > 0 && (
                <div className="flex flex-wrap gap-1">
                  {pack.tags.slice(0, 3).map((tag) => (
                    <span
                      key={tag}
                      className="text-[10px] px-1.5 py-0.5 rounded-full bg-[#2A2D34] text-[#6B7280]"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              )}

              <div className="flex items-center gap-2 pt-1 border-t border-[#2A2D34]">
                <button
                  onClick={() => togglePackActive(pack)}
                  className={`flex items-center gap-1 text-xs px-2 py-1 rounded-full border transition-colors ${
                    pack.is_active
                      ? "bg-[#4ADE80]/10 text-[#4ADE80] border-[#4ADE80]/30"
                      : "bg-red-500/10 text-red-400 border-red-500/30"
                  }`}
                >
                  {pack.is_active ? (
                    <CheckCircle2 className="w-3 h-3" />
                  ) : (
                    <AlertCircle className="w-3 h-3" />
                  )}
                  {pack.is_active ? "Ativo" : "Inativo"}
                </button>
                <div className="ml-auto flex gap-1">
                  <button
                    onClick={() => selectPack(pack)}
                    className="p-1.5 rounded-md text-[#4B5563] hover:text-[#60A5FA] hover:bg-[#60A5FA]/10 transition-colors"
                    title="Gerenciar stickers"
                  >
                    <Image className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => openEditPack(pack)}
                    className="p-1.5 rounded-md text-[#4B5563] hover:text-[#E040FB] hover:bg-[#E040FB]/10 transition-colors"
                    title="Editar"
                  >
                    <Pencil className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => deletePack(pack)}
                    className="p-1.5 rounded-md text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors"
                    title="Excluir"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Pack Form Modal */}
      {showPackForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onClick={() => setShowPackForm(false)}
          />
          <div className="relative bg-[#1C1E22] border border-[#2A2D34] rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto shadow-2xl">
            <div className="flex items-center justify-between px-6 py-4 border-b border-[#2A2D34] sticky top-0 bg-[#1C1E22] z-10">
              <h2 className="font-bold text-white">
                {editingPack ? "Editar Pack" : "Novo Pack de Stickers"}
              </h2>
              <button
                onClick={() => setShowPackForm(false)}
                className="p-1.5 rounded-md text-[#4B5563] hover:text-white hover:bg-[#2A2D34]"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSubmitPack} className="p-6 space-y-4">
              {/* Icon upload */}
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs">Ícone do Pack</Label>
                <div
                  onClick={() => iconInputRef.current?.click()}
                  className="border-2 border-dashed border-[#2A2D34] rounded-xl p-4 flex items-center gap-4 cursor-pointer hover:border-[#E040FB]/50 transition-colors"
                >
                  {iconPreview ? (
                    <>
                      <img
                        src={iconPreview}
                        alt="Icon"
                        className="w-14 h-14 rounded-xl object-cover"
                      />
                      <p className="text-[#9CA3AF] text-sm">
                        Clique para substituir
                      </p>
                    </>
                  ) : (
                    <>
                      <div className="w-14 h-14 rounded-xl bg-[#111214] border border-[#2A2D34] flex items-center justify-center">
                        <Upload className="w-5 h-5 text-[#4B5563]" />
                      </div>
                      <p className="text-[#9CA3AF] text-sm">
                        Clique para enviar ícone
                      </p>
                    </>
                  )}
                  <input
                    ref={iconInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) {
                        setIconFile(f);
                        const reader = new FileReader();
                        reader.onload = (ev) =>
                          setIconPreview(ev.target?.result as string);
                        reader.readAsDataURL(f);
                      }
                    }}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">Nome *</Label>
                  <Input
                    value={packForm.name}
                    onChange={(e) =>
                      setPackForm({ ...packForm, name: e.target.value })
                    }
                    placeholder="Neon Reactions"
                    className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
                    required
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">Autor</Label>
                  <Input
                    value={packForm.author_name}
                    onChange={(e) =>
                      setPackForm({ ...packForm, author_name: e.target.value })
                    }
                    className="bg-[#111214] border-[#2A2D34] text-white h-9"
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs">Descrição</Label>
                <textarea
                  value={packForm.description}
                  onChange={(e) =>
                    setPackForm({ ...packForm, description: e.target.value })
                  }
                  rows={2}
                  className="w-full bg-[#111214] border border-[#2A2D34] text-white text-sm rounded-md px-3 py-2 focus:outline-none focus:border-[#E040FB] placeholder:text-[#4B5563] resize-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">
                    Preço (Coins)
                  </Label>
                  <Input
                    type="number"
                    min={0}
                    value={packForm.price_coins}
                    onChange={(e) =>
                      setPackForm({
                        ...packForm,
                        price_coins: parseInt(e.target.value) || 0,
                      })
                    }
                    className="bg-[#111214] border-[#2A2D34] text-white h-9"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[#9CA3AF] text-xs">Ordem</Label>
                  <Input
                    type="number"
                    value={packForm.sort_order}
                    onChange={(e) =>
                      setPackForm({
                        ...packForm,
                        sort_order: parseInt(e.target.value) || 0,
                      })
                    }
                    className="bg-[#111214] border-[#2A2D34] text-white h-9"
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs">Tags</Label>
                <Input
                  value={packForm.tags}
                  onChange={(e) =>
                    setPackForm({ ...packForm, tags: e.target.value })
                  }
                  placeholder="official, reaction, cute"
                  className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-9"
                />
              </div>

              <div className="flex flex-wrap gap-4">
                {[
                  { key: "is_active", label: "Ativo" },
                  { key: "is_free", label: "Gratuito" },
                  { key: "is_premium_only", label: "Apenas Premium" },
                ].map(({ key, label }) => (
                  <label
                    key={key}
                    className="flex items-center gap-2 cursor-pointer"
                  >
                    <input
                      type="checkbox"
                      checked={packForm[key as keyof PackForm] as boolean}
                      onChange={(e) =>
                        setPackForm({ ...packForm, [key]: e.target.checked })
                      }
                      className="w-4 h-4 rounded border-[#2A2D34] bg-[#111214] accent-[#E040FB]"
                    />
                    <span className="text-[#9CA3AF] text-sm">{label}</span>
                  </label>
                ))}
              </div>

              <div className="flex gap-3 pt-2">
                <Button
                  type="button"
                  variant="ghost"
                  onClick={() => setShowPackForm(false)}
                  className="flex-1 border border-[#2A2D34] text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-10"
                >
                  Cancelar
                </Button>
                <Button
                  type="submit"
                  disabled={submittingPack}
                  className="flex-1 bg-[#E040FB] hover:bg-[#D030EB] text-white h-10"
                >
                  {submittingPack ? (
                    <Loader2 className="w-4 h-4 animate-spin mr-2" />
                  ) : (
                    <Save className="w-4 h-4 mr-2" />
                  )}
                  {editingPack ? "Salvar" : "Criar Pack"}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
