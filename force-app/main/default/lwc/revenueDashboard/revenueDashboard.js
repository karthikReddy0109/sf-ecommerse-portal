import { LightningElement } from 'lwc';
import chartJs from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/RevenueDashboardController.getDashboardData';

export default class RevenueDashboard extends LightningElement {
    dashboardData = null;
    isLoading = false;
    errorMessage;
    lastUpdated;
    refreshInterval;
    isChartJsLoaded = false;
    charts = {}; // store chart instances for cleanup

    async loadDashboard(){
        this.isLoading = true;
        try{
            const dashboardResult = await getDashboardData();
            if(dashboardData.isSuccess){
                this.dashboardData = dashboardResult;
            }else{
                this.errorMessage = dashboardResult.errorMessage;
            }
        }catch(error){
            this.errorMessage = error;
        }finally{
            this.isLoading = false;
        }   
    }

    createCharts(){
        if(this.dashboardData == null) return;
        this.createRevenueLineChart();
        createOrdersDonutChart();
        createTopProductsBarChart();
    }

    createRevenueLineChart(){

    }

    connectedCallback(){
        this.loadDashboard();
        this.refreshInterval = setInterval(() => this.loadDashboard, 60000);
    }

    disconnectedCallback(){
        clearInterval(this.refreshInterval);
        Object.values(this.charts).forEach(chart => chart.destroy());
    }

    renderedCallback(){
        if(this.isChartJsLoaded) return;
        this.isChartJsLoaded = true;
        loadScript(this, chartJs)
        .then(() => {
            this.createCharts();
        })
        .catch(error => {
            console.error('ChartJS load error', error);
        });
    }
}