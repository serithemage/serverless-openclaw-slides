# Slides — Marp PDF export
# Usage: make pdf

.PHONY: pdf

pdf: ## Export slides to PDF
	marp slides.md --theme theme.css --html --allow-local-files --pdf -o slides.pdf
	@echo "✅ slides.pdf"
