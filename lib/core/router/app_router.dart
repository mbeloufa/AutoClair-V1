import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/delete_account_page.dart';
import '../../features/accident_assistant/accident_assistant_page.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/breakdown_assistant/breakdown_assistant_page.dart';
import '../../features/documents/analysis_result_page.dart';
import '../../features/documents/document_upload_page.dart';
import '../../features/eco_driving/eco_driving_page.dart';
import '../../features/home/account_page.dart';
import '../../features/home/action_center_page.dart';
import '../../features/home/history_page.dart';
import '../../features/home/home_page.dart';
import '../../features/home/nearby_page.dart';
import '../../features/home/vehicles_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/parking/parking_page.dart';
import '../../features/start/start_page.dart';
import '../../features/charging_prices/charging_compare_page.dart';
import '../../features/charging_optimizer/charging_optimizer_page.dart';
import '../../features/commercial_offers/commercial_offers_page.dart';
import '../../features/compliance/vehicle_compliance_page.dart';
import '../../features/financial_tools/financial_tools_page.dart';
import '../../features/fuel_optimizer/fuel_optimizer_page.dart';
import '../../features/insurance_review/insurance_review_page.dart';
import '../../features/maintenance_planner/maintenance_planner_page.dart';
import '../../features/quote_comparison/quote_comparison_page.dart';
import '../../features/risk_forecast/risk_forecast_page.dart';
import '../../features/sale_preparation/sale_preparation_page.dart';
import '../../features/used_purchase/used_purchase_page.dart';
import '../../features/vehicle_budget/vehicle_budget_page.dart';
import '../../features/fuel_prices/fuel_price_compare_page.dart';
import '../../features/technical_control/technical_control_compare_page.dart';
import '../../features/theft_assistant/theft_assistant_page.dart';
import '../../features/vehicle_care/vehicle_care_page.dart';
import '../../features/vehicle_care/vehicle_event_form_page.dart';
import '../../features/vehicle_care/vehicle_odometer_page.dart';
import '../../features/vehicle_insights/vehicle_360_page.dart';
import '../../features/vehicle_inspection/vehicle_inspection_page.dart';
import '../../features/trip_readiness/trip_readiness_page.dart';
import '../../features/vehicle_storage/vehicle_storage_page.dart';
import '../../features/technical_control_readiness/technical_control_readiness_page.dart';
import '../../features/workshop_visit/workshop_visit_preparation_page.dart';
import '../../features/tire_care/tire_care_page.dart';
import '../../features/battery_care/battery_care_page.dart';
import '../../features/fluid_care/fluid_care_page.dart';
import '../../features/visibility_care/visibility_care_page.dart';
import '../../features/brake_care/brake_care_page.dart';
import '../../features/body_safety_care/body_safety_care_page.dart';
import '../../features/vehicles/vehicle_form_page.dart';
import '../app_controller.dart';

GoRouter createAppRouter(AppController controller) {
  const publicPaths = <String>{
    '/start',
    '/onboarding',
    '/login',
    '/register',
    '/forgot-password',
  };

  return GoRouter(
    initialLocation: '/start',
    refreshListenable: controller,
    redirect: (context, state) {
      final path = state.uri.path;

      if (path == '/start') {
        if (controller.isAuthenticated) {
          return '/home';
        }
        return controller.onboardingCompleted ? '/login' : '/onboarding';
      }

      if (controller.isAuthenticated) {
        if (publicPaths.contains(path)) {
          return '/home';
        }
        return null;
      }

      if (!controller.onboardingCompleted) {
        if (path != '/onboarding') {
          return '/onboarding';
        }
        return null;
      }

      if (path == '/onboarding') {
        return '/login';
      }

      if (!publicPaths.contains(path)) {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartPage()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingPage(controller: controller),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/actions',
        builder: (context, state) => const ActionCenterPage(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesPage(),
      ),
      GoRoute(
        path: '/vehicles/new',
        builder: (context, state) => const VehicleFormPage(),
      ),
      GoRoute(
        path: '/vehicles/:vehicleId/edit',
        builder: (context, state) =>
            VehicleFormPage(vehicleId: state.pathParameters['vehicleId']),
      ),
      GoRoute(
        path: '/vehicles/:vehicleId/care',
        builder: (context, state) => VehicleCarePage(
          vehicleId: state.pathParameters['vehicleId'] ?? '',
          initialSection: state.uri.queryParameters['section'],
        ),
      ),
      GoRoute(
        path: '/offers',
        builder: (context, state) => const CommercialOffersPage(),
      ),
      GoRoute(
        path: '/vehicles/:vehicleId/offers',
        builder: (context, state) => CommercialOffersPage(
          vehicleId: state.pathParameters['vehicleId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/vehicles/:vehicleId/insight-report',
        builder: (context, state) => Vehicle360Page(
          vehicleId: state.pathParameters['vehicleId'] ?? '',
          initialSection: state.uri.queryParameters['section'],
        ),
      ),
      GoRoute(
        path: '/vehicles/:vehicleId/sale',
        builder: (context, state) => Vehicle360Page(
          vehicleId: state.pathParameters['vehicleId'] ?? '',
          initialSection: 'sale',
        ),
      ),
      GoRoute(
        path: '/vehicles/:vehicleId/care/events/new',
        builder: (context, state) => VehicleEventFormPage(
          vehicleId: state.pathParameters['vehicleId'] ?? '',
          initialEventType: state.extra is String
              ? state.extra as String
              : null,
        ),
      ),
      GoRoute(
        path: '/vehicles/:vehicleId/care/odometer/new',
        builder: (context, state) => VehicleOdometerPage(
          vehicleId: state.pathParameters['vehicleId'] ?? '',
          currentMileage: state.extra is int ? state.extra as int : null,
        ),
      ),
      GoRoute(
        path: '/documents/new',
        builder: (context, state) => const DocumentUploadPage(),
      ),
      GoRoute(path: '/nearby', builder: (context, state) => const NearbyPage()),
      GoRoute(
        path: '/parking',
        builder: (context, state) => const ParkingPage(),
      ),
      GoRoute(
        path: '/technical-controls',
        builder: (context, state) => const TechnicalControlComparePage(),
      ),
      GoRoute(
        path: '/fuel-prices',
        builder: (context, state) => const FuelPriceComparePage(),
      ),
      GoRoute(
        path: '/charging-prices',
        builder: (context, state) => const ChargingComparePage(),
      ),
      GoRoute(
        path: '/savings',
        builder: (context, state) => const FinancialToolsPage(),
      ),
      GoRoute(
        path: '/budget',
        builder: (context, state) => const VehicleBudgetPage(),
      ),
      GoRoute(
        path: '/fuel-optimizer',
        builder: (context, state) => const FuelOptimizerPage(),
      ),
      GoRoute(
        path: '/charging-optimizer',
        builder: (context, state) => const ChargingOptimizerPage(),
      ),
      GoRoute(
        path: '/eco-driving',
        builder: (context, state) => const EcoDrivingPage(),
      ),
      GoRoute(
        path: '/maintenance-planner',
        builder: (context, state) => const MaintenancePlannerPage(),
      ),
      GoRoute(
        path: '/breakdown-assistant',
        builder: (context, state) => const BreakdownAssistantPage(),
      ),
      GoRoute(
        path: '/sale-preparation',
        builder: (context, state) => const SalePreparationPage(),
      ),
      GoRoute(
        path: '/used-purchase',
        builder: (context, state) => const UsedPurchasePage(),
      ),
      GoRoute(
        path: '/accident-assistant',
        builder: (context, state) => const AccidentAssistantPage(),
      ),
      GoRoute(
        path: '/theft-assistant',
        builder: (context, state) => const TheftAssistantPage(),
      ),
      GoRoute(
        path: '/risk-forecast',
        builder: (context, state) => const RiskForecastPage(),
      ),
      GoRoute(
        path: '/vehicle-inspection',
        builder: (context, state) => const VehicleInspectionPage(),
      ),
      GoRoute(
        path: '/trip-readiness',
        builder: (context, state) => const TripReadinessPage(),
      ),
      GoRoute(
        path: '/vehicle-storage',
        builder: (context, state) => const VehicleStoragePage(),
      ),
      GoRoute(
        path: '/technical-control-readiness',
        builder: (context, state) => const TechnicalControlReadinessPage(),
      ),
      GoRoute(
        path: '/workshop-visit',
        builder: (context, state) => const WorkshopVisitPreparationPage(),
      ),
      GoRoute(
        path: '/tire-care',
        builder: (context, state) => const TireCarePage(),
      ),
      GoRoute(
        path: '/battery-care',
        builder: (context, state) => const BatteryCarePage(),
      ),
      GoRoute(
        path: '/fluid-care',
        builder: (context, state) => const FluidCarePage(),
      ),
      GoRoute(
        path: '/visibility-care',
        builder: (context, state) => const VisibilityCarePage(),
      ),
      GoRoute(
        path: '/brake-care',
        builder: (context, state) => const BrakeCarePage(),
      ),
      GoRoute(
        path: '/body-safety-care',
        builder: (context, state) => const BodySafetyCarePage(),
      ),
      GoRoute(
        path: '/compliance',
        builder: (context, state) => const VehicleCompliancePage(),
      ),
      GoRoute(
        path: '/quote-comparison',
        builder: (context, state) => const QuoteComparisonPage(),
      ),
      GoRoute(
        path: '/insurance-review',
        builder: (context, state) => const InsuranceReviewPage(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/history/:documentId/analysis',
        builder: (context, state) => AnalysisResultPage(
          documentId: state.pathParameters['documentId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: '/account/delete',
        builder: (context, state) => const DeleteAccountPage(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Cette page est introuvable.\n${state.uri}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
  );
}
