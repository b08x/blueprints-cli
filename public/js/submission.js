// Submission Page JavaScript

class SubmissionPage {
    constructor() {
        this.app = window.blueprintsApp;
        this.submissionForm = document.getElementById('submissionForm');
        this.metadataForm = document.getElementById('metadataForm');
        this.codeInput = document.getElementById('codeInput');
        this.generateMetadataBtn = document.getElementById('generateMetadataBtn');
        this.blueprintName = document.getElementById('blueprintName');
        this.description = document.getElementById('description');
        this.language = document.getElementById('language');
        this.framework = document.getElementById('framework');
        this.categories = document.getElementById('categories');
        this.clearFormBtn = document.getElementById('clearFormBtn');
        this.submitBlueprintBtn = document.getElementById('submitBlueprintBtn');
        
        this.currentCode = '';
        this.generatedMetadata = null;
        
        this.init();
    }

    init() {
        this.setupEventHandlers();
        this.setupFrameworkDependencies();
    }

    setupEventHandlers() {
        if (this.generateMetadataBtn) {
            this.generateMetadataBtn.addEventListener('click', () => {
                this.handleMetadataGeneration();
            });
        }

        if (this.metadataForm) {
            this.metadataForm.addEventListener('submit', (e) => {
                e.preventDefault();
                this.handleBlueprintSubmission();
            });
        }

        if (this.clearFormBtn) {
            this.clearFormBtn.addEventListener('click', () => {
                this.clearForm();
            });
        }

        if (this.codeInput) {
            this.codeInput.addEventListener('input', () => {
                this.currentCode = this.codeInput.value;
                this.autoResizeTextarea(this.codeInput);
            });
        }

        // Auto-resize description textarea
        if (this.description) {
            this.description.addEventListener('input', () => {
                this.autoResizeTextarea(this.description);
            });
        }
    }

    setupFrameworkDependencies() {
        if (this.language && this.framework) {
            this.language.addEventListener('change', () => {
                this.updateFrameworkOptions();
            });
        }
    }

    updateFrameworkOptions() {
        if (!this.language || !this.framework) return;

        const language = this.language.value;
        const frameworks = this.getFrameworksForLanguage(language);
        
        // Store current selection
        const currentFramework = this.framework.value;
        
        // Clear existing options except the first one
        this.framework.innerHTML = '<option value="">Select Framework</option>';
        
        // Add framework options
        frameworks.forEach(framework => {
            const option = document.createElement('option');
            option.value = framework.value;
            option.textContent = framework.label;
            this.framework.appendChild(option);
        });

        // Restore selection if it's still valid
        if (frameworks.some(fw => fw.value === currentFramework)) {
            this.framework.value = currentFramework;
        }
    }

    getFrameworksForLanguage(language) {
        const frameworkMap = {
            javascript: [
                { value: 'react', label: 'React' },
                { value: 'vue', label: 'Vue.js' },
                { value: 'angular', label: 'Angular' },
                { value: 'svelte', label: 'Svelte' },
                { value: 'express', label: 'Express.js' },
                { value: 'nodejs', label: 'Node.js' }
            ],
            typescript: [
                { value: 'react', label: 'React' },
                { value: 'vue', label: 'Vue.js' },
                { value: 'angular', label: 'Angular' },
                { value: 'svelte', label: 'Svelte' },
                { value: 'express', label: 'Express.js' },
                { value: 'nodejs', label: 'Node.js' }
            ],
            python: [
                { value: 'django', label: 'Django' },
                { value: 'flask', label: 'Flask' },
                { value: 'fastapi', label: 'FastAPI' },
                { value: 'pyramid', label: 'Pyramid' }
            ],
            ruby: [
                { value: 'rails', label: 'Ruby on Rails' },
                { value: 'sinatra', label: 'Sinatra' },
                { value: 'hanami', label: 'Hanami' }
            ],
            go: [
                { value: 'gin', label: 'Gin' },
                { value: 'echo', label: 'Echo' },
                { value: 'fiber', label: 'Fiber' }
            ],
            java: [
                { value: 'spring', label: 'Spring Boot' },
                { value: 'micronaut', label: 'Micronaut' },
                { value: 'quarkus', label: 'Quarkus' }
            ],
            php: [
                { value: 'laravel', label: 'Laravel' },
                { value: 'symfony', label: 'Symfony' },
                { value: 'codeigniter', label: 'CodeIgniter' }
            ],
            csharp: [
                { value: 'aspnet', label: 'ASP.NET Core' },
                { value: 'blazor', label: 'Blazor' }
            ]
        };

        return frameworkMap[language] || [];
    }

    async handleMetadataGeneration() {
        const code = this.codeInput?.value?.trim();
        if (!code) {
            this.app.showMessage('Please enter code before generating metadata.', 'error');
            return;
        }

        // Show loading state
        this.app.showLoading(this.generateMetadataBtn, true);
        this.app.clearMessages();

        try {
            const metadata = await this.app.generateMetadata(code);
            this.generatedMetadata = metadata;
            this.populateMetadataFields(metadata);
            this.app.showMessage('Metadata generated successfully!', 'success');
        } catch (error) {
            console.error('Metadata generation failed:', error);
            this.app.showMessage(`Metadata generation failed: ${error.message}`, 'error');
        } finally {
            this.app.showLoading(this.generateMetadataBtn, false);
        }
    }

    populateMetadataFields(metadata) {
        if (this.blueprintName && metadata.name) {
            this.blueprintName.value = metadata.name;
        }

        if (this.description && metadata.description) {
            this.description.value = metadata.description;
            this.autoResizeTextarea(this.description);
        }

        if (this.language && metadata.language) {
            this.language.value = metadata.language;
            this.updateFrameworkOptions();
        }

        if (this.framework && metadata.framework && metadata.framework !== 'none') {
            // Wait a bit for framework options to be updated
            setTimeout(() => {
                this.framework.value = metadata.framework;
            }, 100);
        }

        if (this.categories && metadata.categories) {
            const categoriesText = Array.isArray(metadata.categories) 
                ? metadata.categories.join(', ')
                : metadata.categories;
            this.categories.value = categoriesText;
        }
    }

    async handleBlueprintSubmission() {
        // Validate required fields
        const name = this.blueprintName?.value?.trim();
        const desc = this.description?.value?.trim();
        const lang = this.language?.value;
        const code = this.codeInput?.value?.trim();

        if (!name || !desc || !lang || !code) {
            this.app.showMessage('Please fill in all required fields.', 'error');
            return;
        }

        // Show loading state
        this.app.showLoading(this.submitBlueprintBtn, true);
        this.app.clearMessages();

        try {
            const blueprintData = {
                name: name,
                description: desc,
                code: code,
                language: lang,
                framework: this.framework?.value || null,
                categories: this.parseCategoriesInput()
            };

            const savedBlueprint = await this.app.createBlueprint(blueprintData);
            
            this.app.showMessage('Blueprint submitted successfully!', 'success');
            
            // Clear form after successful submission
            setTimeout(() => {
                this.clearForm();
                // Optionally redirect to the viewer
                window.location.href = `/viewer?id=${savedBlueprint.id}`;
            }, 2000);
            
        } catch (error) {
            console.error('Blueprint submission failed:', error);
            this.app.showMessage(`Submission failed: ${error.message}`, 'error');
        } finally {
            this.app.showLoading(this.submitBlueprintBtn, false);
        }
    }

    parseCategoriesInput() {
        const categoriesText = this.categories?.value?.trim();
        if (!categoriesText) return [];

        return categoriesText
            .split(',')
            .map(cat => cat.trim())
            .filter(cat => cat.length > 0);
    }

    clearForm() {
        // Clear code input
        if (this.codeInput) {
            this.codeInput.value = '';
            this.currentCode = '';
        }

        // Clear metadata fields
        if (this.blueprintName) this.blueprintName.value = '';
        if (this.description) this.description.value = '';
        if (this.language) this.language.value = '';
        if (this.framework) this.framework.value = '';
        if (this.categories) this.categories.value = '';

        // Reset generated metadata
        this.generatedMetadata = null;

        // Clear messages
        this.app.clearMessages();

        // Reset textarea heights
        if (this.codeInput) this.resetTextareaHeight(this.codeInput);
        if (this.description) this.resetTextareaHeight(this.description);
    }

    autoResizeTextarea(textarea) {
        textarea.style.height = 'auto';
        textarea.style.height = Math.min(textarea.scrollHeight, 500) + 'px';
    }

    resetTextareaHeight(textarea) {
        textarea.style.height = 'auto';
    }

    // Utility method to detect language from code (as fallback)
    detectLanguageFromCode(code) {
        const patterns = {
            javascript: [/function\s+\w+/, /const\s+\w+/, /let\s+\w+/, /=>\s*{/, /require\(/, /import\s+.*from/],
            typescript: [/interface\s+\w+/, /type\s+\w+/, /: string/, /: number/, /: boolean/],
            python: [/def\s+\w+/, /import\s+\w+/, /from\s+\w+\s+import/, /if\s+__name__\s*==\s*["']__main__["']/],
            ruby: [/def\s+\w+/, /class\s+\w+/, /require\s+["']/, /puts\s+/],
            go: [/func\s+\w+/, /package\s+\w+/, /import\s*\(/, /fmt\.Print/],
            java: [/public\s+class/, /public\s+static\s+void\s+main/, /System\.out\.print/],
            php: [/<\?php/, /function\s+\w+/, /echo\s+/, /\$\w+/],
            csharp: [/public\s+class/, /using\s+System/, /Console\.Write/]
        };

        for (const [language, regexes] of Object.entries(patterns)) {
            if (regexes.some(regex => regex.test(code))) {
                return language;
            }
        }

        return 'javascript'; // Default fallback
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new SubmissionPage();
});