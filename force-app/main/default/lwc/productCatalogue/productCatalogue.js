import { LightningElement } from 'lwc';
import searchProducts from '@salesforce/apex/ProductService.searchProducts';
export default class ProductCatalogue extends LightningElement {
    searchTerm = '';
    selectedCategory = '';
    selectedStockStatus = '';
    searchTimeout;
    products = [];
    isLoading = false;
    errorMessage;
    categoryOptions = [
        { label: 'All Categories', value: '' },
        { label: 'Electronics', value: 'Electronics' },
        { label: 'Fashion', value: 'Fashion' },
        { label: 'Home', value: 'Home' },
        { label: 'Sports', value: 'Sports' },
        { label: 'Generic', value: 'Generic' }
    ];
    stockStatusOptions = [
        { label: 'All Stock Status', value: '' },
        { label: 'In Stock', value: 'In Stock' },
        { label: 'Low Stock', value: 'Low Stock' },
        { label: 'Out of Stock', value: 'Out of Stock' }
    ];
    handleSearch(e){
        this.searchTerm = e.target.value;
        window.clearTimeout(this.searchTimeout);
        this.searchTimeout = window.setTimeout(() => {
            this.loadProducts();
        }, 300);
    }

    async loadProducts(){
        try{
            this.isLoading = true;
            const searchResults = await searchProducts({searchTerm: this.searchTerm, category: this.selectedCategory, stockStatus: this.selectedStockStatus});
            this.products = searchResults;
            console.log('Products fetched successfully : ' + searchResults);
            this.isLoading = false;
            this.errorMessage = '';
        }catch(error){
            console.error('Error fetching products:', error);
            this.isLoading = false;
            this.errorMessage = error;
        }
        
    }
    connectedCallback(){
        this.loadProducts();
    }

    handleCategoryChange(e){
        this.selectedCategory = e.detail.value;
        this.loadProducts();
    }

    handleStockStatusChange(e){
        this.selectedStockStatus = e.detail.value;
        this.loadProducts();
    }

    get hasProducts(){
        return this.products.length > 0;
    }

    get noProductsFound(){
        return this.products.length === 0 && !this.isLoading && !this.errorMessage;
    }
}