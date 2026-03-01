# Slides — Marp export
# Usage: make pdf | make html | make pptx | make all

MARP := marp slides.md --theme theme.css --html --allow-local-files

.PHONY: pdf html pptx all clean

all: pdf html pptx ## Export all formats

pdf: ## Export slides to PDF
	$(MARP) --pdf -o slides.pdf
	@echo "✅ slides.pdf"

html: ## Export slides to HTML
	$(MARP) -o slides.html
	@echo "✅ slides.html"

pptx: ## Export slides to PPTX
	$(MARP) --pptx -o slides.pptx
	@echo "✅ slides.pptx"

clean: ## Remove generated files
	rm -f slides.pdf slides.html slides.pptx
