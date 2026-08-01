import { LightningElement } from 'lwc';
import chartJs from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/RevenueDashboardController.getDashboardData';
import { loadScript } from 'lightning/platformResourceLoader';

export default class RevenueDashboard extends LightningElement {
    dashboardData = null;
    isLoading = false;
    errorMessage;
    lastUpdated;
    refreshInterval;
    isChartJsLoaded = false;
    chartJsLoadPromise;
    charts = {}; // store chart instances for cleanup

    async loadDashboard(){
        this.isLoading = true;
        try{
            const dashboardResult = await getDashboardData();
            if(dashboardResult.isSuccess){
                this.dashboardData = dashboardResult;
                this.errorMessage = undefined;
            }else{
                this.dashboardData = null;
                this.errorMessage = dashboardResult.errorMessage;
            }
        }catch(error){
            this.dashboardData = null;
            this.errorMessage = error.body?.message || error.message || 'Unable to load dashboard data.';
        }finally{
            this.isLoading = false;
            const now = new Date();
            this.lastUpdated = now.toLocaleTimeString();
        }   
    }

    createCharts(){
        if(!this.isChartJsLoaded || !this.dashboardData) return;
        this.createRevenueLineChart();
        this.createOrdersDonutChart();
        this.createTopProductsBarChart();
    }

    createRevenueLineChart(){
        const canvas = this.template.querySelector('.revenue-chart-canvas');
        if(!canvas) return;

        if(this.charts.revenue) this.charts.revenue.destroy();

        const labels = this.dashboardData.revenueTrend.map(r => r.monthLabel);
        const data = this.dashboardData.revenueTrend.map(r => r.revenue);

        this.charts.revenue = new window.Chart(canvas.getContext('2d'), {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Revenue (₹)',
                    data: data,
                    borderColor: '#0070d2',
                    backgroundColor: 'rgba(0, 112, 210, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    y: { beginAtZero: true }
                }
            }
        });
    }

    createOrdersDonutChart(){
        const canvas = this.template.querySelector('.orders-chart-canvas');
        if(!canvas) return;

        if(this.charts.orders) this.charts.orders.destroy();

        const labels = this.dashboardData.ordersByStatus.map(s => s.status);
        const data = this.dashboardData.ordersByStatus.map(s => s.count);

        this.charts.orders = new window.Chart(canvas.getContext('2d'), {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: [
                        '#2e844a', // Delivered - green
                        '#0070d2', // Shipped - blue
                        '#dd7a01', // Processing - orange
                        '#706e6b', // Confirmed - grey
                        '#c23934'  // Cancelled - red
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'right' }
                }
            }
        });
    }

    createTopProductsBarChart(){
        const canvas = this.template.querySelector('.products-chart-canvas');
        if(!canvas) return;

        if(this.charts.products) this.charts.products.destroy();

        const labels = this.dashboardData.topProducts.map(s => s.productName);
        const data = this.dashboardData.topProducts.map(s => s.revenue);

        this.charts.products = new window.Chart(canvas.getContext('2d'), {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Revenue (₹)',
                    data: data,
                    backgroundColor: [
                        '#2e844a', // Delivered - green
                        '#0070d2', // Shipped - blue
                        '#dd7a01', // Processing - orange
                        '#706e6b', // Confirmed - grey
                        '#c23934'  // Cancelled - red
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false }
                }
            }
        });
    }

    connectedCallback(){
        this.loadDashboard();
        this.refreshInterval = setInterval(() => this.loadDashboard(), 60000);
    }

    disconnectedCallback(){
        clearInterval(this.refreshInterval);
        Object.values(this.charts).forEach(chart => chart.destroy());
    }

    renderedCallback(){
        if(!this.chartJsLoadPromise){
            this.chartJsLoadPromise = loadScript(this, chartJs)
                .then(() => {
                    if(!window.Chart){
                        throw new Error('The ChartJS static resource did not expose window.Chart.');
                    }
                    this.isChartJsLoaded = true;
                    this.createCharts();
                })
                .catch(error => {
                    this.errorMessage = error.message || 'Unable to load Chart.js.';
                    console.error('ChartJS load error', error);
                });
        }

        if(this.isChartJsLoaded && this.dashboardData){
            this.createCharts();
        }
    }

    get formattedTodayRevenue(){
        return this.dashboardData && this.dashboardData.todayRevenue == null ? '₹ ' + 0 : this.dashboardData.todayRevenue;
    }

    get formattedMonthRevenue(){
        return this.dashboardData && this.dashboardData.monthRevenue == null ? '₹ ' + 0 : this.dashboardData.monthRevenue;
    }

    get formattedQuarterRevenue(){
        return this.dashboardData && this.dashboardData.quarterRevenue == null ? '₹ ' + 0 : this.dashboardData.quarterRevenue;
    }

    get formattedYearRevenue(){
        return this.dashboardData && this.dashboardData.yearRevenue == null ? '₹ ' + 0 : this.dashboardData.yearRevenue;
    }

    handleManualRefresh(){
        this.loadDashboard();
    }
}
