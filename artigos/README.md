# Artigos

Acervo de leitura do projeto: PDFs originais, fichamentos e figuras extraídas.

```
artigos/
├── pdf/       # artigos originais (um arquivo por artigo)
├── notas/     # fichamentos em Markdown (um por artigo, mesmo nome-base)
└── figuras/   # imagens extraídas dos PDFs, quando houver
```

## Convenção de nomes

`<ano>-<primeiro-autor>-<tema-curto>`

Exemplo: `2024-silva-ontologia-molecular.pdf` em `pdf/` e
`2024-silva-ontologia-molecular.md` em `notas/`.

## Regras

- Um artigo por arquivo; nada de PDFs combinados.
- O fichamento em `notas/` referencia o PDF pelo nome-base e traz a citação
  completa no cabeçalho (ABNT), para reaproveitar na escrita.
- Figuras extraídas usam o mesmo prefixo do artigo e um sufixo descritivo:
  `2024-silva-ontologia-molecular-fig2.png`.
- Material de terceiros mantém o aviso de copyright original; este repositório
  é de uso acadêmico.
