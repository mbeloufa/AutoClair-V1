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
import '../../features/smart_trip/smart_trip_page.dart';
import '../../features/legal_support/legal_support_page.dart';
import '../../features/home/vehicles_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/parking/parking_page.dart';
import '../../features/start/start_page.dart';
import '../../features/charging_prices/charging_compare_page.dart';
import '../../features/charging_optimizer/charging_optimizer_page.dart';
import '../../features/commercial_offers/commercial_offers_page.dart';
import '../../features/commercial_offers/purchase_offer_search_page.dart';
import '../../features/compliance/vehicle_compliance_page.dart';
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
import '../widgets/app_state_panel.dart';
import '../../features/tire_care/tire_care_page.dart';
import '../../features/tire_inspection/tire_inspection_page.dart';
import '../../features/premium/premium_page.dart';
import '../../features/battery_care/battery_care_page.dart';
import '../../features/fluid_care/fluid_care_page.dart';
import '../../features/visibility_care/visibility_care_page.dart';
import '../../features/brake_care/brake_care_page.dart';
import '../../features/body_safety_care/body_safety_care_page.dart';
import '../../features/lease_return/lease_return_page.dart';
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
        path: '/vehicles/:vehicleId/tire-inspection',
        builder: (context, state) => TireInspectionPage(
          vehicleId: state.pathParameters['vehicleId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) => const PremiumPage(),
      ),
      GoRoute(
        path: '/offers',
        builder: (context, state) => const PurchaseOfferSearchPage(),
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
      GoRoute(
        path: '/legal-support',
        builder: (context, state) => const LegalSupportPage(),
      ),
      GoRoute(
        path: '/smart-trip',
        builder: (context, state) => const SmartTripPage(),
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
      GoRoute(path: '/savings', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/budget',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const VehicleBudgetPage(),
      ),
      GoRoute(
        path: '/fuel-optimizer',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const FuelOptimizerPage(),
      ),
      GoRoute(
        path: '/charging-optimizer',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const ChargingOptimizerPage(),
      ),
      GoRoute(
        path: '/eco-driving',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const EcoDrivingPage(),
      ),
      GoRoute(
        path: '/maintenance-planner',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const MaintenancePlannerPage(),
      ),
      GoRoute(
        path: '/breakdown-assistant',
        redirect: (context, state) => '/actions',
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
        redirect: (context, state) => '/actions',
        builder: (context, state) => const AccidentAssistantPage(),
      ),
      GoRoute(
        path: '/theft-assistant',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const TheftAssistantPage(),
      ),
      GoRoute(
        path: '/risk-forecast',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const RiskForecastPage(),
      ),
      GoRoute(
        path: '/vehicle-inspection',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const VehicleInspectionPage(),
      ),
      GoRoute(
        path: '/trip-readiness',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const TripReadinessPage(),
      ),
      GoRoute(
        path: '/vehicle-storage',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const VehicleStoragePage(),
      ),
      GoRoute(
        path: '/technical-control-readiness',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const TechnicalControlReadinessPage(),
      ),
      GoRoute(
        path: '/workshop-visit',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const WorkshopVisitPreparationPage(),
      ),
      GoRoute(
        path: '/tire-care',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const TireCarePage(),
      ),
      GoRoute(
        path: '/battery-care',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const BatteryCarePage(),
      ),
      GoRoute(
        path: '/fluid-care',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const FluidCarePage(),
      ),
      GoRoute(
        path: '/visibility-care',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const VisibilityCarePage(),
      ),
      GoRoute(
        path: '/brake-care',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const BrakeCarePage(),
      ),
      GoRoute(
        path: '/body-safety-care',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const BodySafetyCarePage(),
      ),
      GoRoute(
        path: '/lease-return',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const LeaseReturnPage(),
      ),
      GoRoute(
        path: '/compliance',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const VehicleCompliancePage(),
      ),
      GoRoute(
        path: '/quote-comparison',
        redirect: (context, state) => '/actions',
        builder: (context, state) => const QuoteComparisonPage(),
      ),
      GoRoute(
        path: '/insurance-review',
        redirect: (context, state) => '/actions',
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
    errorBuilder: (context, _) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AppStatePanel(
                  key: const ValueKey('route-error-state'),
                  icon: Icons.explore_off_outlined,
                  title: 'Cette page n’est plus disponible',
                  message:
                      'Revenez dans AutoClair pour continuer sans perdre votre suivi.',
                  tone: AppStateTone.warning,
                  primaryActionLabel: 'Revenir à AutoClair',
                  onPrimaryAction: () => context.go('/start'),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
