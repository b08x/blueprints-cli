// Generator Page JavaScript

class GeneratorPage {
    constructor() {
        this.app = window.blueprintsApp;
        this.generationForm = document.getElementById('generationForm');
        this.promptInput = document.getElementById('promptInput');
        this.languageSelect = document.getElementById('languageSelect');
        this.frameworkSelect = document.getElementById('frameworkSelect');
        this.styleSelect = document.getElementById('styleSelect');
        this.generateBtn = document.getElementById('generateBtn');
        this.clearBtn = document.getElementById('clearBtn');
        this.generatedCodeSection = document.getElementById('generatedCodeSection');
        this.generatedCode = document.getElementById('generatedCode');
        this.copyCodeBtn = document.getElementById('copyCodeBtn');
        this.saveAsBlueprint = document.getElementById('saveAsBlueprint');
        this.relevantBlueprints = document.getElementById('relevantBlueprints');
        
        this.currentGeneratedCode = null;
        this.currentGenerationData = null;
        
        this.init();
    }

    init() {
        this.setupEventHandlers();
        this.loadRelevantBlueprints();
        this.setupFrameworkDependencies();
    }

    setupEventHandlers() {
        if (this.generationForm) {
            this.generationForm.addEventListener('submit', (e) => {
                e.preventDefault();
                this.handleGeneration();
            });
        }

        if (this.clearBtn) {
            this.clearBtn.addEventListener('click', () => {
                this.clearForm();
            });
        }

        if (this.copyCodeBtn) {
            this.copyCodeBtn.addEventListener('click', () => {
                if (this.currentGeneratedCode) {
                    this.app.copyToClipboard(this.currentGeneratedCode);
                }
            });
        }

        if (this.saveAsBlueprint) {
            this.saveAsBlueprint.addEventListener('click', () => {
                this.handleSaveAsBlueprint();
            });
        }

        // Auto-resize textarea
        if (this.promptInput) {
            this.promptInput.addEventListener('input', () => {
                this.autoResizeTextarea(this.promptInput);
            });
        }
    }

    setupFrameworkDependencies() {
        if (this.languageSelect && this.frameworkSelect) {
            this.languageSelect.addEventListener('change', () => {
                this.updateFrameworkOptions();
            });
            
            // Initial setup
            this.updateFrameworkOptions();
        }
    }

    updateFrameworkOptions() {
        if (!this.languageSelect || !this.frameworkSelect) return;

        const language = this.languageSelect.value;
        const frameworks = this.getFrameworksForLanguage(language);
        
        // Clear existing options
        this.frameworkSelect.innerHTML = '';
        
        // Add framework options
        frameworks.forEach(framework => {
            const option = document.createElement('option');
            option.value = framework.value;
            option.textContent = framework.label;
            this.frameworkSelect.appendChild(option);
        });
    }

    getFrameworksForLanguage(language) {
        const frameworkMap = {
            javascript: [
                { value: 'react', label: 'React' },
                { value: 'vue', label: 'Vue.js' },
                { value: 'angular', label: 'Angular' },
                { value: 'svelte', label: 'Svelte' },
                { value: 'express', label: 'Express.js' },
                { value: 'none', label: 'Vanilla JavaScript' }
            ],
            typescript: [
                { value: 'react', label: 'React' },
                { value: 'vue', label: 'Vue.js' },
                { value: 'angular', label: 'Angular' },
                { value: 'svelte', label: 'Svelte' },
                { value: 'express', label: 'Express.js' },
                { value: 'none', label: 'TypeScript' }
            ],
            python: [
                { value: 'django', label: 'Django' },
                { value: 'flask', label: 'Flask' },
                { value: 'fastapi', label: 'FastAPI' },
                { value: 'none', label: 'Python' }
            ],
            ruby: [
                { value: 'rails', label: 'Ruby on Rails' },
                { value: 'sinatra', label: 'Sinatra' },
                { value: 'none', label: 'Ruby' }
            ],
            go: [
                { value: 'gin', label: 'Gin' },
                { value: 'echo', label: 'Echo' },
                { value: 'none', label: 'Go' }
            ],
            java: [
                { value: 'spring', label: 'Spring Boot' },
                { value: 'none', label: 'Java' }
            ]
        };

        return frameworkMap[language] || [{ value: 'none', label: 'None' }];
    }

    async handleGeneration() {
        const prompt = this.promptInput?.value?.trim();
        if (!prompt) {
            this.app.showMessage('Please enter a prompt to generate code.', 'error');
            return;
        }

        const language = this.languageSelect?.value || 'javascript';
        const framework = this.frameworkSelect?.value || 'react';

        // Show loading state
        this.app.showLoading(this.generateBtn, true);
        this.app.clearMessages();

        try {
            const result = await this.app.generateCode(prompt, language, framework);
            
            this.currentGeneratedCode = result.code;
            this.currentGenerationData = result;
            
            this.displayGeneratedCode(result);
            this.app.showMessage('Code generated successfully!', 'success');
            
            // Load relevant blueprints based on the prompt
            this.loadRelevantBlueprints(prompt);
            
        } catch (error) {
            console.error('Generation failed:', error);
            this.app.showMessage(`Generation failed: ${error.message}`, 'error');
        } finally {
            this.app.showLoading(this.generateBtn, false);
        }
    }

    displayGeneratedCode(generationData) {
        if (!this.generatedCode || !this.generatedCodeSection) return;

        // Show the generated code section
        this.generatedCodeSection.classList.remove('hidden');

        // Format and display the code
        this.generatedCode.innerHTML = `<pre><code>${this.escapeHtml(generationData.code)}</code></pre>`;

        // Scroll to the generated code section
        this.generatedCodeSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    async handleSaveAsBlueprint() {
        if (!this.currentGeneratedCode || !this.currentGenerationData) {
            this.app.showMessage('No generated code to save.', 'error');
            return;
        }

        // Show loading state
        this.app.showLoading(this.saveAsBlueprint, true);

        try {
            // Generate a name and description for the blueprint
            const prompt = this.promptInput?.value?.trim() || 'Generated code';
            const name = `Generated: ${prompt.substring(0, 50)}${prompt.length > 50 ? '...' : ''}`;
            const description = `Code generated from prompt: "${prompt}"`;
            
            const blueprintData = {
                name: name,
                description: description,
                code: this.currentGeneratedCode,
                language: this.currentGenerationData.language,
                framework: this.currentGenerationData.framework,
                categories: this.generateCategories()
            };

            const savedBlueprint = await this.app.createBlueprint(blueprintData);
            
            this.app.showMessage('Blueprint saved successfully!', 'success');
            
            // Optionally redirect to the viewer
            setTimeout(() => {
                window.location.href = `/viewer?id=${savedBlueprint.id}`;
            }, 2000);
            
        } catch (error) {
            console.error('Failed to save blueprint:', error);
            this.app.showMessage(`Failed to save blueprint: ${error.message}`, 'error');
        } finally {
            this.app.showLoading(this.saveAsBlueprint, false);
        }
    }

    generateCategories() {
        const categories = ['generated'];
        const language = this.languageSelect?.value;
        const framework = this.frameworkSelect?.value;
        const prompt = this.promptInput?.value?.toLowerCase() || '';

        if (language) categories.push(language);
        if (framework && framework !== 'none') categories.push(framework);
        
        // Add categories based on prompt content
        if (prompt.includes('component')) categories.push('component');
        if (prompt.includes('api') || prompt.includes('endpoint')) categories.push('api');
        if (prompt.includes('database') || prompt.includes('db')) categories.push('database');
        if (prompt.includes('auth') || prompt.includes('login')) categories.push('authentication');
        if (prompt.includes('ui') || prompt.includes('interface')) categories.push('ui');

        return categories;
    }

    async loadRelevantBlueprints(searchQuery = '') {
        if (!this.relevantBlueprints) return;

        try {
            // Show loading state
            this.relevantBlueprints.innerHTML = `
                <div class="loading">
                    <div class="spinner"></div>
                    Loading relevant blueprints...
                </div>
            `;

            const blueprints = await this.app.searchBlueprints(searchQuery);
            
            if (blueprints && blueprints.length > 0) {
                // Limit to 6 blueprints
                const limitedBlueprints = blueprints.slice(0, 6);
                this.renderRelevantBlueprints(limitedBlueprints);
            } else {
                this.showNoRelevantBlueprints();
            }
        } catch (error) {
            console.error('Failed to load relevant blueprints:', error);
            this.showRelevantBlueprintsError();
        }
    }

    renderRelevantBlueprints(blueprints) {
        if (!this.relevantBlueprints) return;

        this.relevantBlueprints.innerHTML = '';
        
        blueprints.forEach(blueprint => {
            const card = this.createRelevantBlueprintCard(blueprint);
            this.relevantBlueprints.appendChild(card);
        });
    }

    createRelevantBlueprintCard(blueprint) {
        const card = document.createElement('div');
        card.className = 'card';
        card.style.cssText = 'cursor: pointer; transition: all 0.2s ease;';
        
        card.innerHTML = `
            <div style="display: flex; align-items: center; gap: 1rem;">
                <div style="flex: 1;">
                    <h4 style="font-weight: bold; color: white; margin: 0 0 0.5rem 0; font-size: 1rem;">${blueprint.name || 'Untitled Blueprint'}</h4>
                    <p style="font-size: 0.875rem; color: var(--text-secondary); margin: 0; line-height: 1.4;">
                        ${blueprint.description ? blueprint.description.substring(0, 100) + (blueprint.description.length > 100 ? '...' : '') : 'No description available'}
                    </p>
                </div>
                <div style="width: 3rem; height: 2rem; background: var(--surface-panels); border-radius: 0.25rem; flex-shrink: 0; display: flex; align-items: center; justify-content: center;">
                    <svg style="width: 1.25rem; height: 1.25rem; color: var(--text-secondary);" fill="currentColor" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
                        <path d="M181.66,146.34a8,8,0,0,1,0,11.32l-24,24a8,8,0,0,1-11.32-11.32L164.69,152l-18.35-18.34a8,8,0,0,1,11.32-11.32Zm-72-24a8,8,0,0,0-11.32,0l-24,24a8,8,0,0,0,0,11.32l24,24a8,8,0,0,0,11.32-11.32L91.31,152l18.35-18.34A8,8,0,0,0,109.66,122.34ZM216,88V216a16,16,0,0,1-16,16H56a16,16,0,0,1-16-16V40A16,16,0,0,1,56,24h96a8,8,0,0,1,5.66,2.34l56,56A8,8,0,0,1,216,88Zm-56-8h28.69L160,51.31Zm40,136V96H152a8,8,0,0,1-8-8V40H56V216H200Z"></path>
                    </svg>
                </div>
            </div>
        `;

        card.addEventListener('click', () => {
            window.location.href = `/viewer?id=${blueprint.id}`;
        });

        card.addEventListener('mouseenter', () => {
            card.style.transform = 'translateY(-2px)';
            card.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.3)';
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = 'translateY(0)';
            card.style.boxShadow = 'none';
        });

        return card;
    }

    showNoRelevantBlueprints() {
        if (!this.relevantBlueprints) return;

        this.relevantBlueprints.innerHTML = `
            <div style="text-align: center; padding: 2rem; color: var(--text-secondary);">
                <p>No relevant blueprints found.</p>
                <a href="/submission" class="btn btn-secondary" style="margin-top: 1rem;">Submit Your First Blueprint</a>
            </div>
        `;
    }

    showRelevantBlueprintsError() {
        if (!this.relevantBlueprints) return;

        this.relevantBlueprints.innerHTML = `
            <div style="text-align: center; padding: 2rem; color: var(--text-secondary);">
                <p>Failed to load relevant blueprints.</p>
            </div>
        `;
    }

    clearForm() {
        if (this.promptInput) this.promptInput.value = '';
        if (this.languageSelect) this.languageSelect.value = 'javascript';
        if (this.frameworkSelect) this.frameworkSelect.value = 'react';
        if (this.styleSelect) this.styleSelect.value = 'tailwind';
        if (this.generatedCodeSection) this.generatedCodeSection.classList.add('hidden');
        
        this.currentGeneratedCode = null;
        this.currentGenerationData = null;
        
        this.app.clearMessages();
        this.loadRelevantBlueprints();
    }

    autoResizeTextarea(textarea) {
        textarea.style.height = 'auto';
        textarea.style.height = textarea.scrollHeight + 'px';
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new GeneratorPage();
});