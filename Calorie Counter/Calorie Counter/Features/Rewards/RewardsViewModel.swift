import Foundation

final class RewardsViewModel {
    let screen = Observable<RewardsScreenState?>(nil)
    let statusText = Observable("")

    private let fetchRewardsScreenUseCase: FetchRewardsScreenUseCase

    init(fetchRewardsScreenUseCase: FetchRewardsScreenUseCase) {
        self.fetchRewardsScreenUseCase = fetchRewardsScreenUseCase
    }

    func viewDidLoad() {
        reload()
    }

    func reload() {
        do {
            screen.value = try fetchRewardsScreenUseCase.execute()
            statusText.value = ""
        } catch {
            statusText.value = error.localizedDescription
        }
    }
}
