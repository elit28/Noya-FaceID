#!/usr/bin/env python3
"""Convertit le modèle de reconnaissance SFace (OpenCV Zoo, Apache-2.0) au format Core ML.

Source officielle (Git LFS) :
  https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface
  fichier face_recognition_sface_2021dec.onnx

Le fichier d'entrée est refusé si son empreinte SHA-256 ne correspond pas à celle publiée
par OpenCV Zoo (pointeur Git LFS).

Sortie : Sources/NoyaCore/Resources/FaceRecognition.mlpkgdata (paquet Core ML ML Program,
chargé et compilé à l'exécution par FaceEmbedder).
  - entrée  « input_image » : image RVB 112 × 112, valeurs 0-255 (visage aligné sur les
    5 points du gabarit standard ; la normalisation (x - 127,5) / 128 est intégrée au modèle) ;
  - sortie  « embedding »  : vecteur de 128 valeurs (normalisé ensuite par FaceEmbedder).

Écrit aussi Tests/NoyaCoreTests/Fixtures/sface_reference.json : sortie de référence du
modèle ONNX d'origine (onnxruntime) pour une image synthétique déterministe, afin que les
tests sur macOS vérifient que la version Core ML reste fidèle.

Dépendances (versions testées) :
  python3 -m pip install "torch==2.7.0" "torchvision==0.22.0" --index-url https://download.pytorch.org/whl/cpu
  python3 -m pip install "coremltools==9.0" "onnx==1.23.2" "onnx2torch==1.5.15" onnxruntime numpy
Usage :
  python3 scripts/convert_sface.py chemin/vers/face_recognition_sface_2021dec.onnx
"""
import hashlib
import json
import pathlib
import shutil
import sys

EXPECTED_SHA256 = "0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79"
EXPECTED_SIZE = 38696353
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Sources" / "NoyaCore" / "Resources" / "FaceRecognition.mlpkgdata"
REFERENCE = ROOT / "Tests" / "NoyaCoreTests" / "Fixtures" / "sface_reference.json"


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def synthetic_image():
    """Image RVB 112 × 112 déterministe (dégradés), identique à celle générée par le test Swift."""
    import numpy as np
    y, x = np.mgrid[0:112, 0:112]
    r = (x * 2 + y) % 256
    g = (y * 2 + 37) % 256
    b = (x + y * 3 + 101) % 256
    return np.stack([r, g, b]).astype("float32")[None]  # 1 × 3 × 112 × 112, ordre RVB


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    source = pathlib.Path(sys.argv[1])
    if source.stat().st_size != EXPECTED_SIZE or sha256(source) != EXPECTED_SHA256:
        raise SystemExit(f"Empreinte inattendue pour {source} : fichier refusé.")
    print("Empreinte SHA-256 vérifiée.")

    import coremltools as ct
    import numpy as np
    import onnx
    import onnxruntime
    import torch
    from onnx2torch import convert

    model = onnx.load(source)
    # Export ancien : les poids figurent aussi parmi les entrées du graphe. On les retire
    # pour ne garder que l'image comme entrée.
    initializer_names = {tensor.name for tensor in model.graph.initializer}
    kept = [graph_input for graph_input in model.graph.input if graph_input.name not in initializer_names]
    del model.graph.input[:]
    model.graph.input.extend(kept)
    assert [graph_input.name for graph_input in model.graph.input] == ["data"], "entrée inattendue"

    image = synthetic_image()
    session = onnxruntime.InferenceSession(model.SerializeToString(), providers=["CPUExecutionProvider"])
    reference = session.run(None, {"data": image})[0][0]

    torch_model = convert(model).eval()
    with torch.no_grad():
        torch_output = torch_model(torch.from_numpy(image)).numpy()[0]
    cosine = float(np.dot(reference, torch_output) / (np.linalg.norm(reference) * np.linalg.norm(torch_output)))
    print(f"Fidélité ONNX → PyTorch (cosinus) : {cosine:.6f}")
    if cosine < 0.9999:
        raise SystemExit("Conversion PyTorch infidèle : arrêt.")

    traced = torch.jit.trace(torch_model, torch.from_numpy(image))
    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(name="input_image", shape=(1, 3, 112, 112),
                             color_layout=ct.colorlayout.RGB, scale=1.0, bias=[0.0, 0.0, 0.0])],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS14,
        compute_precision=ct.precision.FLOAT16,
    )
    mlmodel.author = "Yaoyao Zhong (SFace) ; conversion ONNX : OpenCV Zoo ; conversion Core ML : NOYA Face"
    mlmodel.license = "Apache-2.0"
    mlmodel.short_description = (
        "SFace (MobileFaceNet), OpenCV Zoo face_recognition_sface_2021dec.onnx, "
        f"SHA-256 {EXPECTED_SHA256}. Entrée : visage aligné RVB 112×112 (0-255). Sortie : 128 valeurs."
    )
    mlmodel.version = "2021dec"

    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    package = OUTPUT.with_suffix(".mlpackage")
    if package.exists():
        shutil.rmtree(package)
    mlmodel.save(str(package))
    package.rename(OUTPUT)
    print(f"Modèle Core ML écrit : {OUTPUT.relative_to(ROOT)}")

    REFERENCE.write_text(json.dumps({
        "source": "face_recognition_sface_2021dec.onnx",
        "sha256": EXPECTED_SHA256,
        "description": "Sortie onnxruntime (CPU) pour l'image synthétique de convert_sface.py",
        "embedding": [round(float(value), 6) for value in reference],
    }, indent=1) + "\n", encoding="utf-8")
    print(f"Référence écrite : {REFERENCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
