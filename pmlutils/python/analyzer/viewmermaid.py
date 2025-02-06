# <claude>
# File: viewmermaid.py
# Date: 2025-02-04
#
# USER INFO
# - Renders Mermaid diagrams in browser
# - Uses temporary HTML files
# - Uses pml.yaml configuration
# - Enhanced logging support
#
# CONTEXT
# - Development tool for diagram visualization
# - Uses CDN for Mermaid library
# - Browser-based rendering
#
# KEY FEATURES
# - HTML template generation
# - Temporary file management
# - Browser integration
# - Structured logging
# - Configuration from pml.yaml
#
# CLAUDE MODIFICATION HISTORY
# v1.1 - 2025-02-04 - Configuration update
#   * Added pml.yaml support
#   * Added logging system
#   * Improved error handling
# v1.0 - 2025-01-30 12:20 - Initial version
# </claude>

import webbrowser
import tempfile
import os
import logging
from .config import config

class MermaidRenderer:
    def __init__(self):
        self.output_dir = config.output_temp_dir
        self._setup_logging()

        os.makedirs(self.output_dir, exist_ok=True)
        self.logger.info(f"Output directory: {self.output_dir}")

    def _setup_logging(self):
        """Configure le logging."""
        self.logger = logging.getLogger('MermaidRenderer')
        self.logger.setLevel(logging.INFO)

        console_handler = logging.StreamHandler()
        console_handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        ))
        self.logger.addHandler(console_handler)

    def _create_html_template(self, mermaid_code: str) -> str:
        """Crée le template HTML avec le code Mermaid."""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>{config.app_name} - Mermaid Diagram</title>
            <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
            <script>
                mermaid.initialize({{
                    startOnLoad: true,
                    theme: 'base',
                    themeVariables: {{
                        fontSize: '16px',
                        fontFamily: 'arial',
                        nodeBkg: 'transparent',
                        mainBkg: 'transparent',
                        edgeLabelBackground: 'transparent',
                        lineColor: 'black'
                    }}
                }});
            </script>
            <style>
                body {{
                    margin: 20px;
                    font-family: Arial, sans-serif;
                }}
                .mermaid {{
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 80vh;
                }}
            </style>
        </head>
        <body>
            <div class="mermaid">
                {mermaid_code}
            </div>
        </body>
        </html>
        """

    def render(self, mermaid_code: str, title: str = None):
        """
        Rend un diagramme Mermaid dans le navigateur.

        Args:
            mermaid_code (str): Code Mermaid à rendre
            title (str, optional): Titre du fichier temporaire
        """
        self.logger.info("Rendering Mermaid diagram...")

        try:
            html_content = self._create_html_template(mermaid_code)

            # Créer un fichier temporaire dans le répertoire de sortie configuré
            suffix = f"_{title}.html" if title else ".html"
            temp_file_path = os.path.join(self.output_dir, f"mermaid_{config.app_name}{suffix}")

            with open(temp_file_path, 'w', encoding='utf-8') as temp_file:
                temp_file.write(html_content)

            self.logger.info(f"Created temporary file: {temp_file_path}")

            # Ouvrir dans le navigateur
            file_url = f'file://{os.path.abspath(temp_file_path)}'
            self.logger.debug(f"Opening URL: {file_url}")
            webbrowser.open(file_url)

            self.logger.info("Diagram rendered successfully")

        except Exception as e:
            self.logger.error(f"Error rendering Mermaid diagram: {str(e)}")
            raise

def render_mermaid(mermaid_code: str, title: str = None):
    """
    Fonction utilitaire pour rendre rapidement un diagramme Mermaid.
    """
    renderer = MermaidRenderer()
    renderer.render(mermaid_code, title)

# Exemple d'utilisation
if __name__ == "__main__":
    example_diagram = """
    sequenceDiagram
        participant U as User
        participant P as PuzzleBoard
        participant G as GameStateNotifier
        participant I as ImageProcessingNotifier
        
        U->>P: Tap piece
        P->>G: swapPieces()
        G->>G: updateArrangement
        G-->>P: state update
        P->>P: rebuild UI
    """

    render_mermaid(example_diagram, "puzzle_sequence")